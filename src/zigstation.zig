const std = @import("std");
const Memory = @import("memory.zig").Memory;
const CPU = @import("cpu.zig").CPU;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = &gpa.allocator;

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len < 2) {
        std.debug.warn("A BIOS file was not provided.\n\n", .{});
        std.debug.warn("USAGE:\n", .{});
        std.debug.warn("    zigstation <bios_file>\n", .{});
        std.os.exit(1);
    }

    var bios_file_handle = try std.fs.openFileAbsolute(args[1], std.fs.File.OpenFlags{ .read = true });
    defer bios_file_handle.close();

    const bios = try bios_file_handle.readToEndAlloc(alloc, 10_000_000);
    defer alloc.free(bios);

    var memory = Memory.init(bios);
    var cpu = CPU.init(&memory);

    while (true) {
        cpu.step();
    }
}
