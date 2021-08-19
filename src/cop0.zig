const Exception = @import("exception.zig").Exception;
const panic = @import("std").debug.panic;
const print = @import("std").debug.print;

pub const COP0 = struct {
    status_register: u32,
    // Cause register for exceptions
    cause: u32,
    // Return address from exception
    epc: u32,

    pub fn init() COP0 {
        return COP0{
            .status_register = 0,
            .cause = 0,
            .epc = 0,
        };
    }

    pub fn write_register(self: *COP0, register: u5, data: u32) void {
        switch (register) {
            // 0 disables these so only panic when the value isn't 0
            3, 5, 6, 7, 9, 11, 13 => if (data != 0) {
                panic("Non 0 write to cop0 register: {} , data: {}\n", .{ register, data });
            },
            12 => self.status_register = data,
            14 => self.epc = data,
            else => panic("Writing cop0 register {} is not supported\n", .{register}),
        }
    }

    pub fn read_register(self: *COP0, register: u5) u32 {
        switch (register) {
            12 => return self.status_register,
            13 => return self.cause,
            14 => return self.epc,
            else => panic("Reading cop0 register {} is not supported\n", .{register}),
        }
    }

    pub fn cache_isloated(self: *COP0) bool {
        return ((self.status_register >> 16) & 0x01) == 1;
    }

    pub fn set_exception_code(self: *COP0, cause: Exception) void {
        // TODO: This completely overrides the cause register. Should it really do that ?
        self.cause = @intCast(u32, @enumToInt(cause)) << 2;
    }
};
