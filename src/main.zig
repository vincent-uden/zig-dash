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

    const screenWidth = 800;
    const screenHeight = 450;

    var entries = try journal.sample_journal_entries(allocator);
    defer entries.deinit(allocator);
    std.debug.print("Found {} journal entries\n", .{entries.items.len});

    var stats = journal.collect_stats(entries.items);

    const local = try zeit.local(allocator, &env);

    var last_ran_journal_job: zeit.Instant = (try zeit.instant(.{})).in(&local);
    const job_interval: zeit.Duration = .{
        .seconds = 20,
    };

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow();

    const mediumFont = try rl.loadFontEx("./assets/fonts/static/Geist-Medium.ttf", 20, null);
    const boldFont = try rl.loadFontEx("./assets/fonts/static/Geist-Black.ttf", 20, null);

    var tmp_alloc: std.heap.ArenaAllocator = .init(std.heap.page_allocator);

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        // Update
        const now = (try zeit.instant(.{})).in(&local);
        if (now.time().compare((try last_ran_journal_job.add(job_interval)).time()) == .after) {
            var formatted: std.ArrayList(u8) = .empty;
            try now.time().strftime(formatted.writer(allocator), "%Y-%m-%d %H:%M:%S %Z");

            entries = try journal.sample_journal_entries(allocator);
            stats = journal.collect_stats(entries.items);

            last_ran_journal_job = (try zeit.instant(.{})).in(&local);
        }

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.{ .r = 0x31, .b = 0x31, .g = 0x31, .a = 255 });

        const label = try std.fmt.allocPrintSentinel(tmp_alloc.allocator(), "Found {} journal entries", .{entries.items.len}, 0);
        rl.drawTextEx(boldFont, label, .{ .x = 10, .y = 10 }, 20, 1.0, .light_gray);

        const success_lbl = try std.fmt.allocPrintSentinel(tmp_alloc.allocator(), "Sucessful entries {}", .{stats.success_n}, 0);
        const error_lbl = try std.fmt.allocPrintSentinel(tmp_alloc.allocator(), "Error entries {}", .{stats.error_n}, 0);
        rl.drawTextEx(mediumFont, success_lbl, .{ .x = 10, .y = 30 }, 20, 1.0, .green);
        rl.drawTextEx(mediumFont, error_lbl, .{ .x = 10, .y = 50 }, 20, 1.0, .red);

        if (stats.last_error != null) {
            var last_error_time: std.ArrayList(u8) = .empty;
            try stats.last_error.?.strftime(last_error_time.writer(tmp_alloc.allocator()), "%Y-%m-%d %H:%M:%S %Z");
            const last_error_lbl = try std.fmt.allocPrintSentinel(tmp_alloc.allocator(), "Last error occured at {s}", .{last_error_time.items}, 0);
            rl.drawTextEx(mediumFont, last_error_lbl, .{ .x = 10, .y = 70 }, 20, 1.0, .red);
        }

        _ = tmp_alloc.reset(.retain_capacity);
    }
}

test {
    _ = journal;
}
