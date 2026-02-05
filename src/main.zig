const std = @import("std");
const zig_dash = @import("zig_dash");
const rl = @import("raylib");
const zeit = @import("zeit");
const journal = @import("./journal.zig");

pub fn main() anyerror!void {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();

    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    const now = try zeit.instant(.{});
    std.debug.print("{}\n", .{now});

    const screenWidth = 800;
    const screenHeight = 450;

    var entries = try journal.journal_entries_for_unit(allocator, .{ .unit_name = "mullvad-daemon" });
    defer entries.deinit(allocator);
    std.debug.print("Found {} journal entries\n", .{entries.items.len});

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        // Update

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.dark_gray);

        rl.drawFPS(10, 10);
        rl.drawText("Congrats! You created your first window!", 190, 200, 20, .light_gray);
    }
}
