const std = @import("std");
const zeit = @import("zeit");

pub const JournalEntry = struct {
    allocator: std.mem.Allocator,
    buffer: []u8,
    timestamp: zeit.Time,
    hostname: []const u8,
    unit: []const u8,
    message: []const u8,

    fn from_str(allocator: std.mem.Allocator, buffer: []u8) anyerror!JournalEntry {
        var iterator = std.mem.splitScalar(u8, buffer, ' ');
        const iso_timestamp = try (iterator.next() orelse error.ParsingError);
        const hostname = try (iterator.next() orelse error.ParsingError);
        const unit = try (iterator.next() orelse error.ParsingError);

        const timestamp = try zeit.Time.fromISO8601(iso_timestamp);

        const out: JournalEntry = .{ .allocator = allocator, .buffer = buffer, .hostname = hostname, .unit = unit, .timestamp = timestamp, .message = iterator.rest() };

        return out;
    }

    fn deinit(self: *JournalEntry) void {
        self.allocator.free(self.buffer);
    }
};

pub fn journal_entries_for_unit(allocator: std.mem.Allocator, args: struct { unit_name: []const u8 = "" }) anyerror!std.ArrayList(JournalEntry) {
    var journal_args = [_][]const u8{ "journalctl", "--no-pager", "--output=short-iso", "-u", args.unit_name };

    var child = std.process.Child.init(if (args.unit_name.len > 0) journal_args[0..] else journal_args[0..3], allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();

    var stdout_buffer: [1024]u8 = undefined;
    var rdr_wrapper = child.stdout.?.reader(&stdout_buffer);
    const rdr: *std.Io.Reader = &rdr_wrapper.interface;
    const out = parse_journal_lines(allocator, rdr);
    _ = try child.wait();
    return out;
}

pub fn parse_journal_lines(allocator: std.mem.Allocator, rdr: *std.Io.Reader) anyerror!std.ArrayList(JournalEntry) {
    var out: std.ArrayList(JournalEntry) = .empty;
    while ((rdr.peekByte() catch 0) != 0) {
        const line = rdr.takeDelimiterExclusive('\n') catch |err| {
            switch (err) {
                error.StreamTooLong => {
                    _ = try rdr.discardDelimiterInclusive('\n');
                    continue;
                },
                else => {
                    std.process.exit(1);
                },
            }
        };
        // Toss the newline
        rdr.toss(1);
        if (std.mem.startsWith(u8, line, "-- Boot")) {
            continue;
        }
        const newLine = try allocator.alloc(u8, line.len);
        @memcpy(newLine, line);

        try out.append(allocator, JournalEntry.from_str(allocator, newLine) catch |err| {
            std.debug.print("Couldn't parse line: \"{s}\"\n", .{line});
            return err;
        });
    }
    return out;
}

pub fn sample_journal_entries(allocator: std.mem.Allocator) anyerror!std.ArrayList(JournalEntry) {
    var file = try std.fs.cwd().openFile("./assets/sample_journalctl_lines.txt", .{ .mode = .read_only });
    defer file.close();
    var buffer: [1024]u8 = undefined;
    var rdr: std.fs.File.Reader = file.reader(&buffer);
    return try parse_journal_lines(allocator, &rdr.interface);
}

const expect = std.testing.expect;

test "Can parse sample journalctl lines" {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();

    const entries = try sample_journal_entries(allocator);
    try expect(entries.items.len > 0);

    try expect(entries.items[0].timestamp.year == 2026);
    try std.testing.expectEqualStrings("vincent", entries.items[0].hostname);
    try std.testing.expectEqualStrings("cli_client[2836]:", entries.items[0].unit);
    try std.testing.expectEqualStrings("[DEBUG] get_account_data", entries.items[0].message);
}
