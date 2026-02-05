const std = @import("std");
const zig_dash = @import("zig_dash");
const rl = @import("raylib");

const zeit = @import("zeit");

const JournalJobResult = struct {
    timestamp: []u8,
    success: bool,
};

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    const now = try zeit.instant(.{});
    std.debug.print("{}", .{now});

    const screenWidth = 800;
    const screenHeight = 450;

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
