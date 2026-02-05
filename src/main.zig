const rl = @import("raylib");
const std = @import("std");
const zeit = @import("zeit");
const zig_dash = @import("zig_dash");

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

    var entries = try journal.sample_journal_entries(allocator);
    defer entries.deinit(allocator);
    std.debug.print("Found {} journal entries\n", .{entries.items.len});

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow();

    const mediumFont = try rl.loadFontEx("./assets/fonts/static/Geist-Medium.ttf", 20, null);
    const boldFont = try rl.loadFontEx("./assets/fonts/static/Geist-Black.ttf", 20, null);

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        // Update

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.dark_gray);

        rl.drawFPS(10, 10);
        rl.drawTextEx(mediumFont, "Congrats! You created your first window!", .{ .x = 190, .y = 200 }, 20, 1.0, .light_gray);
        rl.drawTextEx(boldFont, "Congrats!", .{ .x = 190, .y = 240 }, 20, 1.0, .light_gray);
    }
}

test {
    _ = journal;
}
