const std = @import("std");
const zeit = @import("zeit");

pub const JournalEntry = struct {
    buffer: []u8,
    timestamp: zeit.Time,
    hostname: []const u8,
    unit: []const u8,
    message: []const u8,

    fn from_str(buffer: []u8) anyerror!JournalEntry {
        var iterator = std.mem.splitScalar(u8, buffer, ' ');
        const iso_timestamp = try (iterator.next() orelse error.ParsingError);
        const hostname = try (iterator.next() orelse error.ParsingError);
        const unit = try (iterator.next() orelse error.ParsingError);

        const timestamp = try zeit.Time.fromISO8601(iso_timestamp);

        const out: JournalEntry = .{ .buffer = buffer, .hostname = hostname, .unit = unit, .timestamp = timestamp, .message = "" };

        return out;
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
        try out.append(allocator, JournalEntry.from_str(line) catch |err| {
            std.debug.print("Couldn't parse line: \"{s}\"\n", .{line});
            return err;
        });
    }
    return out;
}

test "Can parse sample journalctl lines" {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();

    var file = std.fs.cwd().openFile("./assets/sample_journalctl_lines.txt", .{ .mode = .read_only });
    defer file.close();
    var buffer: [1024]u8 = undefined;
    var rdr: std.fs.File.Reader = file.reader(&buffer);

    std.testing.expect((try parse_journal_lines(allocator, &rdr)).items.len == 0);

    parse_journal_lines(allocator, rdr);
}
