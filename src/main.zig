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

    var tmp_alloc: std.heap.ArenaAllocator = .init(std.heap.page_allocator);

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        // Update

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.dark_gray);

        const label = try std.fmt.allocPrintSentinel(tmp_alloc.allocator(), "Found {} journal entries", .{entries.items.len}, 0);
        rl.drawTextEx(boldFont, label, .{ .x = 10, .y = 10 }, 20, 1.0, .light_gray);

        var i: i64 = 0;
        for (entries.items) |entry| {
            std.debug.print("{any}", .{entry});
            const entryLbl = try std.fmt.allocPrintSentinel(tmp_alloc.allocator(), "{s}", .{entry.hostname}, 0);
            rl.drawTextEx(mediumFont, entryLbl, .{ .x = 10, .y = @as(f32, @floatFromInt(i)) * 20 }, 20, 1.0, .light_gray);
            i += 1;
        }

        _ = tmp_alloc.reset(.retain_capacity);
    }
}

test {
    _ = journal;
}
