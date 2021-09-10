const COP0 = @import("cop0.zig").COP0;
const Instruction = @import("instruction.zig").Instruction;
const Memory = @import("memory.zig").Memory;
const Exception = @import("exception.zig").Exception;
const panic = @import("std").debug.panic;
const print = @import("std").debug.print;

const reset_vector = 0xBFC0_0000;

pub const CPU = struct {
    memory: *Memory,
    cop0: COP0,
    exception_pc: u32,
    pc: u32,
    pc_next: u32,
    registers: [32]u32,
    lo: u32,
    hi: u32,
    branching: bool,
    in_delay_slot: bool,

    pub fn init(memory: *Memory) CPU {
        return CPU{
            .memory = memory,
            .cop0 = COP0.init(),
            .exception_pc = reset_vector,
            .pc = reset_vector,
            .pc_next = reset_vector + 4,
            .registers = [_]u32{0} ** 32,
            .lo = 0,
            .hi = 0,
            .branching = false,
            .in_delay_slot = false,
        };
    }

    pub fn step(self: *CPU) void {
        const instruction = Instruction.init(self.memory.read(u32, self.pc));

        self.in_delay_slot = self.branching;
        self.branching = false;

        self.exception_pc = self.pc;
        self.pc = self.pc_next;
        self.pc_next += 4;

        switch (instruction.opcode()) {
            0x00 => switch (instruction.secondary_opcode()) {
                0x00 => self.sll(instruction.rd(), instruction.rt(), instruction.shift_amount()),
                0x02 => self.srl(instruction.rd(), instruction.rt(), instruction.shift_amount()),
                0x03 => self.sra(instruction.rd(), instruction.rt(), instruction.shift_amount()),
                0x04 => self.sllv(instruction.rs(), instruction.rt(), instruction.rd()),
                0x06 => self.srlv(instruction.rs(), instruction.rt(), instruction.rd()),
                0x07 => self.srav(instruction.rs(), instruction.rt(), instruction.rd()),
                0x08 => self.jr(instruction.rs()),
                0x09 => self.jalr(instruction.rs(), instruction.rd()),
                0x0C => self.syscall(),
                0x0D => self.break_op(),
                0x10 => self.mfhi(instruction.rd()),
                0x11 => self.mthi(instruction.rs()),
                0x12 => self.mflo(instruction.rd()),
                0x13 => self.mtlo(instruction.rs()),
                0x18 => self.mult(instruction.rs(), instruction.rt()),
                0x19 => self.multu(instruction.rs(), instruction.rt()),
                0x1A => self.div(instruction.rs(), instruction.rt()),
                0x1B => self.divu(instruction.rs(), instruction.rt()),
                0x20 => self.add(instruction.rs(), instruction.rt(), instruction.rd()),
                0x21 => self.addu(instruction.rs(), instruction.rt(), instruction.rd()),
                0x22 => self.sub(instruction.rs(), instruction.rt(), instruction.rd()),
                0x23 => self.subu(instruction.rs(), instruction.rt(), instruction.rd()),
                0x24 => self.and_op(instruction.rs(), instruction.rt(), instruction.rd()),
                0x25 => self.or_op(instruction.rs(), instruction.rt(), instruction.rd()),
                0x26 => self.xor(instruction.rs(), instruction.rt(), instruction.rd()),
                0x27 => self.nor(instruction.rs(), instruction.rt(), instruction.rd()),
                0x2A => self.slt(instruction.rs(), instruction.rt(), instruction.rd()),
                0x2B => self.sltu(instruction.rs(), instruction.rt(), instruction.rd()),
                else => panic("Unknown secondary opcode: {}\n", .{instruction}),
            },
            0x01 => switch (instruction.rt()) {
                0x00 => self.bltz(instruction.rs(), instruction.imm_signed()),
                0x01 => self.bgez(instruction.rs(), instruction.imm_signed()),
                0x10 => self.bltzal(instruction.rs(), instruction.imm_signed()),
                0x11 => self.bgezal(instruction.rs(), instruction.imm_signed()),
                else => panic("Unknown branch condition instruction: {}\n", .{instruction}),
            },
            0x02 => self.jump(instruction.target()),
            0x03 => self.jal(instruction.target()),
            0x04 => self.beq(instruction.rs(), instruction.rt(), instruction.imm_signed()),
            0x05 => self.bne(instruction.rs(), instruction.rt(), instruction.imm_signed()),
            0x06 => self.blez(instruction.rs(), instruction.imm_signed()),
            0x07 => self.bgtz(instruction.rs(), instruction.imm_signed()),
            0x08 => self.addi(instruction.rs(), instruction.rt(), instruction.imm_signed()),
            0x09 => self.addiu(instruction.rs(), instruction.rt(), instruction.imm_signed()),
            0x0A => self.slti(instruction.rs(), instruction.rt(), instruction.imm_signed()),
            0x0B => self.sltiu(instruction.rs(), instruction.rt(), instruction.imm_signed()),
            0x0C => self.andi(instruction.rs(), instruction.rt(), instruction.imm()),
            0x0D => self.ori(instruction.rs(), instruction.rt(), instruction.imm()),
            0x0E => self.xori(instruction.rs(), instruction.rt(), instruction.imm()),
            0x0F => self.lui(instruction.rt(), instruction.imm()),
            0x10 => switch (instruction.cop_opcode()) {
                0x00 => self.mfc0(instruction.rt(), instruction.rd()),
                0x04 => self.mtc0(instruction.rt(), instruction.rd()),
                0x10 => self.rfe(instruction.data),
                else => panic("Unknown cop0 opcode: {}\n", .{instruction}),
            },
            0x11 => self.cop1(),
            0x12 => self.cop2(),
            0x13 => self.cop3(),
            0x20 => self.lb(instruction.rs(), instruction.rt(), instruction.imm_signed()),
            0x21 => self.lh(instruction.rs(), instruction.rt(), instruction.imm_signed()),
            0x23 => self.lw(instruction.rs(), instruction.rt(), instruction.imm_signed()),
            0x24 => self.lbu(instruction.rs(), instruction.rt(), instruction.imm_signed()),
            0x25 => self.lhu(instruction.rs(), instruction.rt(), instruction.imm_signed()),
            0x28 => self.sb(instruction.rs(), instruction.rt(), instruction.imm_signed()),
            0x29 => self.sh(instruction.rs(), instruction.rt(), instruction.imm_signed()),
            0x2B => self.sw(instruction.rs(), instruction.rt(), instruction.imm_signed()),
            else => panic("Unknown instruction: {}\n", .{instruction}),
        }
    }

    // Shift Word Left Logical
    fn sll(self: *CPU, rd: u5, rt: u5, sa: u5) void {
        self.set_register(rd, self.registers[rt] << sa);
    }

    // Shift Word Right Logical
    fn srl(self: *CPU, rd: u5, rt: u5, sa: u5) void {
        self.set_register(rd, self.registers[rt] >> sa);
    }

    // Shift Word Right Arithmetic
    fn sra(self: *CPU, rd: u5, rt: u5, sa: u5) void {
        const msb = self.registers[rt] & 0x8000_0000;
        var shifts = sa;
        var result = self.registers[rt];
        while (shifts > 0) {
            result = (result >> 1) | msb;
            shifts -= 1;
        }
        self.set_register(rd, result);
    }

    // Shift Word Left Logical Variable
    fn sllv(self: *CPU, rs: u5, rt: u5, rd: u5) void {
        self.set_register(rd, self.registers[rt] << @intCast(u5, (self.registers[rs] & 0x1F)));
    }

    // Shift Word Right Logical Variable
    fn srlv(self: *CPU, rs: u5, rt: u5, rd: u5) void {
        self.set_register(rd, self.registers[rt] >> @intCast(u5, (self.registers[rs] & 0x1F)));
    }

    // Shift Word Right Arithmetic Variable
    fn srav(self: *CPU, rs: u5, rt: u5, rd: u5) void {
        const msb = self.registers[rt] & 0x8000_0000;
        var shifts = self.registers[rs] & 0x1F;
        var result = self.registers[rt];
        while (shifts > 0) {
            result = (result >> 1) | msb;
            shifts -= 1;
        }
        self.set_register(rd, result);
    }

    // Jump Register
    fn jr(self: *CPU, rs: u5) void {
        self.branching = true;
        self.pc_next = self.registers[rs];
    }

    // Jump And Link Register
    fn jalr(self: *CPU, rs: u5, rd: u5) void {
        self.set_register(rd, self.pc_next);
        self.branching = true;
        self.pc_next = self.registers[rs];
    }

    // SYSCALL
    fn syscall(self: *CPU) void {
        self.exception(Exception.syscall);
    }

    // BREAK
    fn break_op(self: *CPU) void {
        self.exception(Exception.break_op);
    }

    // Move From HI
    fn mfhi(self: *CPU, rd: u5) void {
        self.set_register(rd, self.hi);
    }

    // Move To HI
    fn mthi(self: *CPU, rs: u5) void {
        self.hi = self.registers[rs];
    }

    // Move From LO
    fn mflo(self: *CPU, rd: u5) void {
        self.set_register(rd, self.lo);
    }

    // Move To LO
    fn mtlo(self: *CPU, rs: u5) void {
        self.lo = self.registers[rs];
    }

    // Multiply
    fn mult(self: *CPU, rs: u5, rt: u5) void {
        const x: i64 = @intCast(i64, @bitCast(i32, self.registers[rs]));
        const y: i64 = @intCast(i64, @bitCast(i32, self.registers[rt]));

        const result = @bitCast(u64, x * y);

        self.lo = @intCast(u32, result & 0x0000_0000_FFFF_FFFF);
        self.hi = @intCast(u32, result >> 32);
    }

    // Multiply Unsigned Word
    fn multu(self: *CPU, rs: u5, rt: u5) void {
        const x: u64 = @intCast(u64, self.registers[rs]);
        const y: u64 = @intCast(u64, self.registers[rt]);

        const result = x * y;

        self.lo = @intCast(u32, result & 0x0000_0000_FFFF_FFFF);
        self.hi = @intCast(u32, result >> 32);
    }

    // Divide Word
    fn div(self: *CPU, rs: u5, rt: u5) void {
        const numerator: i32 = @bitCast(i32, self.registers[rs]);
        const divisor: i32 = @bitCast(i32, self.registers[rt]);

        if (divisor == 0) {
            // TODO: Divide by 0 is undefined in documentation, but other emulators seem to have some sort of behavior for this ?
            self.lo = 0;
            self.hi = 0;
        } else {
            // TODO: How to handle -2147483648 / -1 ?
            self.lo = @bitCast(u32, @divTrunc(numerator, divisor));
            self.hi = @bitCast(u32, @rem(numerator, divisor));
        }
    }

    // Divide Word Unsigned
    fn divu(self: *CPU, rs: u5, rt: u5) void {
        const numerator = self.registers[rs];
        const divisor = self.registers[rt];

        if (divisor == 0) {
            // TODO: Divide by 0 is undefined in documentation, but other emulators seem to have some sort of behavior for this ?
            self.lo = 0;
            self.hi = 0;
        } else {
            self.lo = numerator / divisor;
            self.hi = @rem(numerator, divisor);
        }
    }

    // Add Word
    fn add(self: *CPU, rs: u5, rt: u5, rd: u5) void {
        var result: i32 = undefined;
        const rs_i32: i32 = @bitCast(i32, self.registers[rs]);
        const rt_i32: i32 = @bitCast(i32, self.registers[rt]);
        if (@addWithOverflow(i32, rt_i32, rs_i32, &result)) {
            self.exception(Exception.overflow);
        } else {
            self.set_register(rd, @bitCast(u32, result));
        }
    }

    // Add Unsigned Word
    fn addu(self: *CPU, rs: u5, rt: u5, rd: u5) void {
        self.set_register(rd, self.registers[rs] +% self.registers[rt]);
    }

    // Subtract Word
    fn sub(self: *CPU, rs: u5, rt: u5, rd: u5) void {
        var result: i32 = undefined;
        const rs_i32: i32 = @bitCast(i32, self.registers[rs]);
        const rt_i32: i32 = @bitCast(i32, self.registers[rt]);
        if (@addWithOverflow(i32, rs_i32, rt_i32, &result)) {
            self.exception(Exception.overflow);
        } else {
            self.set_register(rd, @bitCast(u32, result));
        }
    }

    // Subtract Unsigned Word
    fn subu(self: *CPU, rs: u5, rt: u5, rd: u5) void {
        self.set_register(rd, self.registers[rs] -% self.registers[rt]);
    }

    // AND
    fn and_op(self: *CPU, rs: u5, rt: u5, rd: u5) void {
        self.set_register(rd, self.registers[rs] & self.registers[rt]);
    }

    // OR
    fn or_op(self: *CPU, rs: u5, rt: u5, rd: u5) void {
        self.set_register(rd, self.registers[rs] | self.registers[rt]);
    }

    // XOR
    fn xor(self: *CPU, rs: u5, rt: u5, rd: u5) void {
        self.set_register(rd, self.registers[rs] ^ self.registers[rt]);
    }

    // NOR
    fn nor(self: *CPU, rs: u5, rt: u5, rd: u5) void {
        self.set_register(rd, ~(self.registers[rs] | self.registers[rt]));
    }

    // Set On Less Than
    fn slt(self: *CPU, rs: u5, rt: u5, rd: u5) void {
        const signed_rs: i32 = @bitCast(i32, self.registers[rs]);
        const signed_rt: i32 = @bitCast(i32, self.registers[rt]);
        if (signed_rs < signed_rt) {
            self.set_register(rd, 1);
        } else {
            self.set_register(rd, 0);
        }
    }

    // Set On Less Than Unsigned
    fn sltu(self: *CPU, rs: u5, rt: u5, rd: u5) void {
        if (self.registers[rs] < self.registers[rt]) {
            self.set_register(rd, 1);
        } else {
            self.set_register(rd, 0);
        }
    }

    // Branch On Less Than Zero
    fn bltz(self: *CPU, rs: u5, imm_signed: i16) void {
        if (self.registers[rs] >> 31 == 1) {
            self.branching = true;
            self.pc_next = self.pc +% (@bitCast(u32, @as(i32, imm_signed) << 2));
        }
    }

    // Branch On Greater Than Or Equal To Zero
    fn bgez(self: *CPU, rs: u5, imm_signed: i16) void {
        if (self.registers[rs] >> 31 == 0) {
            self.branching = true;
            self.pc_next = self.pc +% (@bitCast(u32, @as(i32, imm_signed) << 2));
        }
    }

    // Branch On Less Than Zero And Link
    fn bltzal(self: *CPU, rs: u5, imm_signed: i16) void {
        if (self.registers[rs] >> 31 == 1) {
            self.set_register(31, self.pc_next);
            self.branching = true;
            self.pc_next = self.pc +% (@bitCast(u32, @as(i32, imm_signed) << 2));
        }
    }

    // Branch On Greater Than Or Equal To Zero And Link
    fn bgezal(self: *CPU, rs: u5, imm_signed: i16) void {
        if (self.registers[rs] >> 31 == 0) {
            self.set_register(31, self.pc_next);
            self.branching = true;
            self.pc_next = self.pc +% (@bitCast(u32, @as(i32, imm_signed) << 2));
        }
    }

    // Jump
    fn jump(self: *CPU, target: u26) void {
        self.branching = true;
        self.pc_next = (self.pc & 0xF000_0000) | (@as(u32, target) << 2);
    }

    // Jump and Link
    fn jal(self: *CPU, target: u26) void {
        self.set_register(31, self.pc_next);
        self.jump(target);
    }

    // Branch On Equal
    fn beq(self: *CPU, rs: u5, rt: u5, imm_signed: i16) void {
        if (self.registers[rs] == self.registers[rt]) {
            self.branching = true;
            self.pc_next = self.pc +% (@bitCast(u32, @as(i32, imm_signed) << 2));
        }
    }

    // Branch On Not Equal
    fn bne(self: *CPU, rs: u5, rt: u5, imm_signed: i16) void {
        if (self.registers[rs] != self.registers[rt]) {
            self.branching = true;
            self.pc_next = self.pc +% (@bitCast(u32, @as(i32, imm_signed) << 2));
        }
    }

    // Branch on Less Than or Equal To Zero
    fn blez(self: *CPU, rs: u5, imm_signed: i16) void {
        if (self.registers[rs] >> 31 == 1 or self.registers[rs] == 0) {
            self.branching = true;
            self.pc_next = self.pc +% (@bitCast(u32, @as(i32, imm_signed) << 2));
        }
    }

    // Branch On Greater Than Zero
    fn bgtz(self: *CPU, rs: u5, imm_signed: i16) void {
        if (self.registers[rs] >> 31 == 0 and self.registers[rs] != 0) {
            self.branching = true;
            self.pc_next = self.pc +% (@bitCast(u32, @as(i32, imm_signed) << 2));
        }
    }

    // Add Immediate
    fn addi(self: *CPU, rs: u5, rt: u5, imm_signed: i16) void {
        var result: i32 = undefined;
        var imm_signed_i32: i32 = @as(i32, imm_signed);
        if (@addWithOverflow(i32, @bitCast(i32, self.registers[rs]), imm_signed_i32, &result)) {
            panic("ADDI overflow should throw exception. Still need to implement this\n", .{});
        } else {
            self.set_register(rt, @bitCast(u32, result));
        }
    }

    // Add Immediate Upper
    fn addiu(self: *CPU, rs: u5, rt: u5, imm_signed: i16) void {
        self.set_register(rt, wrapping_add(self.registers[rs], imm_signed));
    }

    // Set On Less Than Immediate
    fn slti(self: *CPU, rs: u5, rt: u5, imm_signed: i16) void {
        if (@bitCast(i32, self.registers[rs]) < @intCast(i32, imm_signed)) {
            self.set_register(rt, 1);
        } else {
            self.set_register(rt, 0);
        }
    }

    // Set On Less Than Immediate Unsigned
    fn sltiu(self: *CPU, rs: u5, rt: u5, imm_signed: i16) void {
        if (self.registers[rs] < imm_signed) {
            self.set_register(rt, 1);
        } else {
            self.set_register(rt, 0);
        }
    }

    // AND immediate
    fn andi(self: *CPU, rs: u5, rt: u5, imm: u16) void {
        self.set_register(rt, self.registers[rs] & @as(u32, imm));
    }

    // OR Immediate
    fn ori(self: *CPU, rs: u5, rt: u5, imm: u16) void {
        self.set_register(rt, self.registers[rs] | @as(u32, imm));
    }

    // Exclusive OR Immediate
    fn xori(self: *CPU, rs: u5, rt: u5, imm: u16) void {
        self.set_register(rt, self.registers[rs] ^ @as(u32, imm));
    }

    // Load Upper Intermediate
    fn lui(self: *CPU, rt: u5, imm: u16) void {
        self.set_register(rt, @as(u32, imm) << 16);
    }

    // Move from coprocessor 0
    fn mfc0(self: *CPU, rt: u5, rd: u5) void {
        self.registers[rt] = self.cop0.read_register(rd);
    }

    // Move to coprocessor 0
    fn mtc0(self: *CPU, rt: u5, rd: u5) void {
        self.cop0.write_register(rd, self.registers[rt]);
    }

    // Restore From Exception
    fn rfe(self: *CPU, instruction: u32) void {
        // Other insutrctions could actually happen here, but they are virtual memory related.
        // The PSX doesn't use virtual memory so we panic in case the program tries to use them.
        if (instruction & 0x0000_003F != 0x0000_0010) {
            panic("No RFE instruction encountered when it was expected: 0b{b:0>32}\n", .{instruction});
        }

        const status_register = self.cop0.read_register(12);
        const mode_interrupt_flags = status_register & 0x0000_003F;
        const updated_mode_interrupt_flags = (mode_interrupt_flags >> 2) & 0x0000_003F;
        const updated_status_register = (status_register & 0xFFFF_FFC0) | updated_mode_interrupt_flags;
        self.cop0.write_register(12, updated_status_register);
    }

    fn cop1(self: *CPU) void {
        self.exception(Exception.coprocessor_unusable);
    }

    fn cop2(self: *CPU) void {
        _ = self;
        panic("Not handling COP2 opcodes", .{});
    }

    fn cop3(self: *CPU) void {
        self.exception(Exception.coprocessor_unusable);
    }

    // Load Byte
    fn lb(self: *CPU, rs: u5, rt: u5, imm_signed: i16) void {
        if (self.cop0.cache_isloated()) {
            print("Not running LB instruction because cache is isolated.\n", .{});
            return;
        }

        const address = wrapping_add(self.registers[rs], imm_signed);
        const data = @bitCast(u32, @intCast(i32, @bitCast(i8, self.memory.read(u8, address))));
        self.set_register(rt, data);
    }

    // Load Halfword
    fn lh(self: *CPU, rs: u5, rt: u5, imm_signed: i16) void {
        if (self.cop0.cache_isloated()) {
            print("Not running LH instruction because cache is isolated.\n", .{});
            return;
        }

        const address = wrapping_add(self.registers[rs], imm_signed);

        if (@rem(address, 2) == 0) {
            const data = @bitCast(u32, @intCast(i32, @bitCast(i16, self.memory.read(u16, address))));
            self.set_register(rt, data);
        } else {
            self.exception(Exception.address_error_load);
        }
    }

    // Load Word
    fn lw(self: *CPU, rs: u5, rt: u5, imm_signed: i16) void {
        if (self.cop0.cache_isloated()) {
            print("Not running LW instruction because cache is isolated.\n", .{});
            return;
        }

        const address = wrapping_add(self.registers[rs], imm_signed);

        if (@rem(address, 4) == 0) {
            self.set_register(rt, self.memory.read(u32, address));
        } else {
            self.exception(Exception.address_error_load);
        }
    }

    // Load Byte Unsigned
    fn lbu(self: *CPU, rs: u5, rt: u5, imm_signed: i16) void {
        if (self.cop0.cache_isloated()) {
            print("Not running LBU instruction because cache is isolated.\n", .{});
            return;
        }

        const address = wrapping_add(self.registers[rs], imm_signed);
        self.set_register(rt, self.memory.read(u8, address));
    }

    // Load Halfword Unsigned
    fn lhu(self: *CPU, rs: u5, rt: u5, imm_signed: i16) void {
        if (self.cop0.cache_isloated()) {
            print("Not running LHU instruction because cache is isolated.\n", .{});
            return;
        }

        const address = wrapping_add(self.registers[rs], imm_signed);

        if (@rem(address, 2) == 0) {
            self.set_register(rt, self.memory.read(u16, address));
        } else {
            self.exception(Exception.address_error_load);
        }
    }

    // Store Byte
    fn sb(self: *CPU, rs: u5, rt: u5, imm_signed: i16) void {
        if (self.cop0.cache_isloated()) {
            print("Not running SB instruction because cache is isolated.\n", .{});
            return;
        }
        const address = wrapping_add(self.registers[rs], imm_signed);
        const data = @intCast(u8, self.registers[rt] & 0x0000_00FF);
        self.memory.write(u8, address, data);
    }

    // Store Halfword
    fn sh(self: *CPU, rs: u5, rt: u5, imm_signed: i16) void {
        if (self.cop0.cache_isloated()) {
            print("Not running SH instruction because cache is isolated\n", .{});
            return;
        }

        const address = wrapping_add(self.registers[rs], imm_signed);

        if (@rem(address, 2) == 0) {
            const data: u16 = @intCast(u16, self.registers[rt] & 0x0000_FFFF);
            self.memory.write(u16, address, data);
        } else {
            self.exception(Exception.address_error_store);
        }
    }

    // Store Word
    fn sw(self: *CPU, rs: u5, rt: u5, imm_signed: i16) void {
        if (self.cop0.cache_isloated()) {
            print("Not running SW instruction because cache is isolated\n", .{});
            return;
        }

        const address = wrapping_add(self.registers[rs], imm_signed);

        if (@rem(address, 4) == 0) {
            self.memory.write(u32, address, self.registers[rt]);
        } else {
            self.exception(Exception.address_error_store);
        }
    }

    fn set_register(self: *CPU, register: u5, value: u32) void {
        self.registers[register] = value;
        self.registers[0] = 0;
    }

    fn exception(self: *CPU, cause: Exception) void {
        var status_register = self.cop0.read_register(12);
        var epc = self.exception_pc;

        // The SR register contains flags for the last 3 set of interrupt enable and user mode bits.
        // The flags work like a stack 3 deep. When an exception occurs old ones get rotated out and new ones come in.
        const mode_interrupt_flags = status_register & 0x0000_003F;
        const updated_mode_interrupt_flags = (mode_interrupt_flags << 2) & 0x0000_003F;
        status_register = (status_register & 0xFFFF_FFC0) | updated_mode_interrupt_flags;

        // Setup cause
        self.cop0.set_exception_code(cause);

        // There are other addresses, but they don't need implemented. They are based off of TLB misses which
        // don't apply to the PSX because the TLB is for virtual memory which the PSX doesn't use.
        const boot_exception_vector_bit = (status_register >> 22) & 1;
        const exception_vector: u32 = if (boot_exception_vector_bit == 1) 0xBFC0_0180 else 0x8000_0080;
        self.pc = exception_vector;
        self.pc_next = self.pc +% 4;

        if (self.in_delay_slot) {
            epc = epc -% 4;

            // Set BD flag on SR
            status_register |= (1 << 31);
        }

        // Set EPC
        self.cop0.write_register(14, epc);

        // Set the status register
        self.cop0.write_register(12, status_register);
    }
};

fn wrapping_add(x: u32, y: i16) u32 {
    return x +% @bitCast(u32, @as(i32, y));
}
