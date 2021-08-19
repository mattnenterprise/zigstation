const Memory = @import("memory.zig").Memory;
const panic = @import("std").debug.panic;

pub const CPU = struct {
    memory: *Memory,

    pub fn init(memory: *Memory) CPU {
        return CPU{
            .memory = memory,

        };
    }

    pub fn step(self: *CPU) void {
        _ = self;
        panic("CPU not implemented\n", .{});
    }
};