const std = @import("std");

pub const Instruction = struct {
    data: u32,

    pub fn init(instruction: u32) Instruction {
        return Instruction{
            .data = instruction,
        };
    }

    pub fn opcode(self: Instruction) u6 {
        return @intCast(u6, self.data >> 26) & 0b111111;
    }

    pub fn secondary_opcode(self: Instruction) u6 {
        return @intCast(u6, self.data & 0x0000_003F);
    }

    pub fn cop_opcode(self: Instruction) u5 {
        return @intCast(u5, (self.data >> 21) & 0x0000_001F);
    }

    pub fn rd(self: Instruction) u5 {
        return @intCast(u5, (self.data >> 11) & 0x0000_001F);
    }

    pub fn rs(self: Instruction) u5 {
        return @intCast(u5, (self.data >> 21) & 0x0000_001F);
    }

    pub fn rt(self: Instruction) u5 {
        return @intCast(u5, (self.data >> 16) & 0x0000_001F);
    }

    pub fn imm(self: Instruction) u16 {
        return @intCast(u16, self.data & 0xFFFF);
    }

    pub fn imm_signed(self: Instruction) i16 {
        return @bitCast(i16, @intCast(u16, self.data & 0x0000_FFFF));
    }

    pub fn shift_amount(self: Instruction) u5 {
        return @intCast(u5, (self.data >> 6) & 0x0000_001F);
    }

    pub fn target(self: Instruction) u26 {
        return @intCast(u26, self.data & 0x03FF_FFFF);
    }

    pub fn format(self: Instruction, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("0b{b:0>32}", .{self.data});
    }
};
