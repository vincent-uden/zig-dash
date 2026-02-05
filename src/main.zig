const std = @import("std");
const zig_dash = @import("zig_dash");
const rl = @import("raylib");

const zeit = @import("zeit");

const JournalEntry = struct {
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

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    const now = try zeit.instant(.{});
    std.debug.print("{}\n", .{now});

    const screenWidth = 800;
    const screenHeight = 450;

    // Call journalctl
    var child = std.process.Child.init(&[_][]const u8{ "journalctl", "--no-pager", "--output=short-iso" }, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();

    var stdout_buffer: [1024]u8 = undefined;
    var rdr_wrapper = child.stdout.?.reader(&stdout_buffer);
    const rdr: *std.Io.Reader = &rdr_wrapper.interface;
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
        const entry = try JournalEntry.from_str(line);
        std.debug.print("{}\n", .{entry});
    }

    _ = try child.wait();

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        // Update

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.white);

        rl.drawText("Congrats! You created your first window!", 190, 200, 20, .light_gray);
    }
}
