const panic = @import("std").debug.panic;
const print = @import("std").debug.print;

pub const Memory = struct {
    bios: []u8,
    ram: [2048 * 1024]u8,

    pub fn init(bios: []u8) Memory {
        return Memory{
            .bios = bios,
            .ram = [_]u8{0x00} ** (2048 * 1024),
        };
    }

    pub fn read(self: *Memory, comptime T: type, address: u32) T {
        const unmirrored_address = unmirror_address(address);

        if (unmirrored_address >= 0x1F00_0000 and unmirrored_address < 0x1F80_0000) {
            switch (T) {
                u8 => return 0xFF,
                u16 => return 0xFFFF,
                u32 => return 0xFFFF_FFFF,
                else => @compileError("Only supported types are u8, u16, and u32"),
            }
        } else if (unmirrored_address >= 0x1F80_1070 and unmirrored_address <= 0x1F80_1074) {
            print("Not reading from IRQ I/O map\n", .{});
            return 0;
        } else if (unmirrored_address >= 0x1F80_1080 and unmirrored_address < 0x1F80_10FF) {
            print("Not reading DMA registers\n", .{});
            return 0;
        } else if (unmirrored_address >= 0x1F80_1810 and unmirrored_address < 0x1F80_1818) {
            print("Not reading from GPU registers\n", .{});
            switch (unmirrored_address) {
                0x1F80_1814 => {
                    switch (T) {
                        u8 => return 0x00,
                        u16 => return 0x0000,
                        u32 => return 0x1000_0000,
                        else => @compileError("Only supported types are u8, u16, and u32"),
                    }
                },
                else => return 0,
            }
        } else if (unmirrored_address >= 0x1F80_1C00 and unmirrored_address < 0x1F80_1DBF) {
            print("Not reading SPU control register\n", .{});
            return 0;
        } else if (unmirrored_address >= 0x1FC0_0000 and unmirrored_address < 0x1FC8_0000) {
            return read_io(T, self.bios, unmirrored_address, 0x1FC0_0000);
        } else if (unmirrored_address >= 0x00000000 and unmirrored_address < 0x00200000) {
            return read_io(T, &self.ram, unmirrored_address, 0x00000000);
        } else {
            panic("Cannot read data for address: 0x{X:0>8}\n", .{address});
        }
    }

    pub fn write(self: *Memory, comptime T: type, address: u32, data: T) void {
        const unmirrored_address = unmirror_address(address);

        if (unmirrored_address >= 0x1F801000 and unmirrored_address < 0x1F802000) {
            print("I/O port memory writes not supported: 0x{X:0>8}\n", .{address});
        } else if (unmirrored_address >= 0x1F802000 and unmirrored_address < 0x1F804000) {
            print("Expansion Region 2 memory writes not supported: 0x{X:0>8}\n", .{address});
        } else if (unmirrored_address >= 0x00000000 and unmirrored_address < 0x00200000) {
            write_io(T, data, &self.ram, unmirrored_address, 0x00000000);
        } else if (address >= 0xFFFE0000) {
            print("I/O port cache control write not supported: 0x{X:0>8}\n", .{address});
        } else {
            panic("Cannot write data to address: 0x{X:0>8}\n", .{address});
        }
    }
};

fn read_io(comptime T: type, section: []u8, offset: u32, begin: u32) T {
    var data: T = 0;

    switch (T) {
        u8 => {
            data = section[offset - begin];
        },
        u16 => {
            data |= @as(u16, section[offset - begin]);
            data |= (@as(u16, section[offset - begin + 1]) << 8);
        },
        u32 => {
            data |= @as(u32, section[offset - begin]);
            data |= (@as(u32, section[offset - begin + 1]) << 8);
            data |= (@as(u32, section[offset - begin + 2]) << 16);
            data |= (@as(u32, section[offset - begin + 3]) << 24);
        },
        else => @compileError("Only supported types are u8, u16, and u32"),
    }

    return data;
}

fn write_io(comptime T: type, data: T, section: []u8, offset: u32, begin: u32) void {
    switch (T) {
        u8 => {
            section[offset - begin] = data;
        },
        u16 => {
            section[offset - begin] = @intCast(u8, data & 0x0000_00FF);
            section[offset - begin + 1] = @intCast(u8, data >> 8 & 0x0000_00FF);
        },
        u32 => {
            section[offset - begin] = @intCast(u8, data & 0x0000_00FF);
            section[offset - begin + 1] = @intCast(u8, data >> 8 & 0x0000_00FF);
            section[offset - begin + 2] = @intCast(u8, data >> 16 & 0x0000_00FF);
            section[offset - begin + 3] = @intCast(u8, data >> 24 & 0x0000_00FF);
        },
        else => @compileError("Only supported types are u8, u16, and u32"),
    }
}

// Coverts a mirrored KSEG0 and KSEG1 address to KUSEG address. It keeps all KSEG2 addresses the same.
// TODO: This assumes the scratchpad is mirrored to KSEG1, but it actually isn't.
fn unmirror_address(address: u32) u32 {
    // The 512MB section we are in.
    var section = address >> 29;
    if (section == 4 or section == 5) {
        return address & 0x1FFF_FFFF;
    }
    return address;
}
