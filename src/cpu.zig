const std = @import("std");
const builtin = @import("builtin");
const dbg = builtin.mode == std.builtin.OptimizeMode.Debug;

const Bus = @import("bus.zig").Bus;

const Registers = struct {
    const STACK_BASE: u16 = 0x0100;
    const STACK_RESET: u8 = 0xFD;

    pc: u16,
    sp: u8,
    a: u8,
    x: u8,
    y: u8,

    pub fn init() Registers {
        return Registers{
            .pc = 0,
            .sp = STACK_RESET,
            .a = 0,
            .x = 0,
            .y = 0,
        };
    }
};

const Flags = packed struct {
    carry: bool,
    zero: bool,
    interrupt_disable: bool,
    decimal_mode: bool,
    break1: bool,
    break2: bool,
    overflow: bool,
    negative: bool,

    pub fn init() Flags {
        return Flags{
            .carry = false,
            .zero = false,
            .interrupt_disable = true,
            .decimal_mode = false,
            .break1 = false,
            .break2 = true,
            .overflow = false,
            .negative = false,
        };
    }
};

const OpCode = struct {
    name: *const [4:0]u8,
    instruction: *const anyopaque,
    memory: *const anyopaque,
    cycles: u8,
};

pub const Cpu = struct {
    reg: Registers,
    flags: Flags,
    cycles: u64,
    bus: *Bus,
    binary: if (dbg) [8]u8 else void,
    assembly: if (dbg) [32]u8 else void,
    opcode: if (dbg) u8 else void,

    pub fn init(bus: *Bus) Cpu {
        return Cpu{
            .reg = Registers.init(),
            .flags = Flags.init(),
            .cycles = 0,
            .bus = bus,
            .binary = undefined,
            .assembly = undefined,
            .opcode = undefined,
        };
    }

    fn pc_consume(self: *Cpu, val: u16) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc +%= val;
        return pc;
    }

    fn make_binary(self: *Cpu, a: u8, b: ?u8, c: ?u8) void {
        std.debug.assert(dbg);
        var b_str: [2]u8 = [_]u8{' '} ** 2;
        if (b != null) {
            _ = std.fmt.bufPrint(&b_str, "{X:0>2}", .{b.?}) catch {};
        }
        var c_str: [2]u8 = [_]u8{' '} ** 2;
        if (c != null) {
            _ = std.fmt.bufPrint(&c_str, "{X:0>2}", .{c.?}) catch {};
        }
        _ = std.fmt.bufPrint(&self.binary, "{X:0>2} {s} {s}", .{ a, b_str, c_str }) catch {};
    }

    fn local_jump(
        self: *Cpu,
        instruction: *const fn (*Cpu) void,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        if (dbg) {
            const bin: u8 = self.bus.cpu_read_u8(self.reg.pc);
            self.make_binary(self.opcode, bin, null);
            const addr: u16 = @bitCast(@as(i16, @bitCast(self.reg.pc +% 1)) +% @as(i8, @bitCast(bin)));
            _ = std.fmt.bufPrint(&self.assembly, "{s} ${X:0>4}", .{ name, addr }) catch {};
        }
        instruction(self);
    }

    fn long_jump(
        self: *Cpu,
        instruction: *const fn (*Cpu, u16) void,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        const addr: u16 = self.bus.cpu_read_u16(self.pc_consume(2));
        if (dbg) {
            self.make_binary(self.opcode, @truncate(addr & 0xFF), @truncate(addr >> 8));
            _ = std.fmt.bufPrint(&self.assembly, "{s} ${X:0>4}", .{ name, addr }) catch {};
        }
        instruction(self, addr);
    }

    fn subroutine_jump(
        self: *Cpu,
        instruction: *const fn (*Cpu, u16) void,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        const addr: u16 = self.bus.cpu_read_u16(self.reg.pc);
        if (dbg) {
            self.make_binary(self.opcode, @truncate(addr & 0xFF), @truncate(addr >> 8));
            _ = std.fmt.bufPrint(&self.assembly, "{s} ${X:0>4}", .{ name, addr }) catch {};
        }
        instruction(self, addr);
    }

    fn no_memory(
        self: *Cpu,
        instruction: *const fn (*Cpu) void,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        if (dbg) {
            self.make_binary(self.opcode, null, null);
            _ = std.fmt.bufPrint(&self.assembly, "{s}", .{name}) catch {};
        }
        instruction(self);
    }

    fn no_memory_a(
        self: *Cpu,
        instruction: *const fn (*Cpu) void,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        if (dbg) {
            self.make_binary(self.opcode, null, null);
            _ = std.fmt.bufPrint(&self.assembly, "{s} A", .{name}) catch {};
        }
        instruction(self);
    }

    fn immediate(
        self: *Cpu,
        instruction: *const fn (*Cpu, u16) void,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        const addr: u16 = self.pc_consume(1);
        if (dbg) {
            const bin: u8 = self.bus.cpu_read_u8(addr);
            self.make_binary(self.opcode, bin, null);
            _ = std.fmt.bufPrint(&self.assembly, "{s} #${X:0>2}", .{ name, bin }) catch {};
        }
        instruction(self, addr);
    }

    fn zero_page(
        self: *Cpu,
        instruction: *const fn (*Cpu, u16) void,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        const addr: u8 = self.bus.cpu_read_u8(self.pc_consume(1));
        if (dbg) {
            self.make_binary(self.opcode, addr, null);
            _ = std.fmt.bufPrint(
                &self.assembly,
                "{s} ${X:0>2} = {X:0>2}",
                .{ name, addr, self.bus.cpu_read_u8(addr) },
            ) catch {};
        }
        instruction(self, addr);
    }

    fn zero_page_x(
        self: *Cpu,
        instruction: *const fn (*Cpu, u16) void,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        const addr: u8 = self.bus.cpu_read_u8(self.pc_consume(1)) +% self.reg.x;
        if (dbg) {
            const bin: u8 = self.bus.cpu_read_u8(self.reg.pc - 1);
            self.make_binary(self.opcode, bin, null);
            _ = std.fmt.bufPrint(
                &self.assembly,
                "{s} ${X:0>2},X @ {X:0>2} = {X:0>2}",
                .{ name, bin, addr, self.bus.cpu_read_u8(addr) },
            ) catch {};
        }
        instruction(self, addr);
    }

    fn zero_page_y(
        self: *Cpu,
        instruction: *const fn (*Cpu, u16) void,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        const addr: u8 = self.bus.cpu_read_u8(self.pc_consume(1)) +% self.reg.y;
        if (dbg) {
            const bin: u8 = self.bus.cpu_read_u8(self.reg.pc - 1);
            self.make_binary(self.opcode, bin, null);
            _ = std.fmt.bufPrint(
                &self.assembly,
                "{s} ${X:0>2},Y @ {X:0>2} = {X:0>2}",
                .{ name, bin, addr, self.bus.cpu_read_u8(addr) },
            ) catch {};
        }
        instruction(self, addr);
    }

    fn absolute(
        self: *Cpu,
        instruction: *const fn (*Cpu, u16) void,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        const addr: u16 = self.bus.cpu_read_u16(self.pc_consume(2));
        if (dbg) {
            self.make_binary(self.opcode, @truncate(addr & 0xFF), @truncate(addr >> 8));
            _ = std.fmt.bufPrint(
                &self.assembly,
                "{s} ${X:0>4} = {X:0>2}",
                .{ name, addr, self.bus.cpu_read_u8(addr) },
            ) catch {};
        }
        instruction(self, addr);
    }

    fn absolute_x(
        self: *Cpu,
        instruction: *const fn (*Cpu, u16) void,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        const addr: u16 = self.bus.cpu_read_u16(self.pc_consume(2)) +% @as(u16, self.reg.x);
        if (dbg) {
            const bin: u16 = self.bus.cpu_read_u16(self.reg.pc - 2);
            self.make_binary(self.opcode, @truncate(bin & 0xFF), @truncate(bin >> 8));
            _ = std.fmt.bufPrint(
                &self.assembly,
                "{s} ${X:0>4},X @ {X:0>4} = {X:0>2}",
                .{ name, bin, addr, self.bus.cpu_read_u8(addr) },
            ) catch {};
        }
        instruction(self, addr);
    }

    fn absolute_y(
        self: *Cpu,
        instruction: *const fn (*Cpu, u16) void,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        const addr: u16 = self.bus.cpu_read_u16(self.pc_consume(2)) +% @as(u16, self.reg.y);
        if (dbg) {
            const bin: u16 = self.bus.cpu_read_u16(self.reg.pc - 2);
            self.make_binary(self.opcode, @truncate(bin & 0xFF), @truncate(bin >> 8));
            _ = std.fmt.bufPrint(
                &self.assembly,
                "{s} ${X:0>4},Y @ {X:0>4} = {X:0>2}",
                .{ name, bin, addr, self.bus.cpu_read_u8(addr) },
            ) catch {};
        }
        instruction(self, addr);
    }

    fn indirect(
        self: *Cpu,
        instruction: *const fn (*Cpu, u16) void,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        // indirect mode is bugged af
        const ref: u16 = self.bus.cpu_read_u16(self.pc_consume(2));
        var deref: u16 = undefined;
        if (ref & 0x00FF == 0x00FF) {
            const lo: u16 = self.bus.cpu_read_u8(ref);
            const hi: u16 = self.bus.cpu_read_u8(ref & 0xFF00);
            deref = (hi << 8) | lo;
        } else {
            deref = self.bus.cpu_read_u16(ref);
        }
        if (dbg) {
            self.make_binary(self.opcode, @truncate(ref & 0xFF), @truncate(ref >> 8));
            _ = std.fmt.bufPrint(&self.assembly, "{s} (${X:0>4}) = {X:0>4}", .{ name, ref, deref }) catch {};
        }
        instruction(self, deref);
    }

    fn indirect_x(
        self: *Cpu,
        instruction: *const fn (*Cpu, u16) void,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        const ptr: u8 = self.bus.cpu_read_u8(self.pc_consume(1)) +% self.reg.x;
        const hi: u16 = @as(u16, self.bus.cpu_read_u8(ptr +% 1)) << 8;
        const lo: u16 = @as(u16, self.bus.cpu_read_u8(ptr));
        const addr: u16 = hi | lo;
        if (dbg) {
            const bin: u8 = self.bus.cpu_read_u8(self.reg.pc - 1);
            self.make_binary(self.opcode, bin, null);
            _ = std.fmt.bufPrint(
                &self.assembly,
                "{s} (${X:0>2},X) @ {X:0>2} = {X:0>4} = {X:0>2}",
                .{ name, bin, bin +% self.reg.x, addr, self.bus.cpu_read_u8(addr) },
            ) catch {};
        }
        instruction(self, addr);
    }

    fn indirect_y(
        self: *Cpu,
        instruction: *const fn (*Cpu, u16) void,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        const ptr: u8 = self.bus.cpu_read_u8(self.pc_consume(1));
        const hi: u16 = @as(u16, self.bus.cpu_read_u8(ptr +% 1)) << 8;
        const lo: u16 = @as(u16, self.bus.cpu_read_u8(ptr));
        const addr: u16 = (hi | lo) +% @as(u16, self.reg.y);
        if (dbg) {
            const bin: u16 = self.bus.cpu_read_u8(self.reg.pc - 1);
            self.make_binary(self.opcode, @truncate(bin), null);
            _ = std.fmt.bufPrint(
                &self.assembly,
                "{s} (${X:0>2}),Y = {X:0>4} @ {X:0>4} = {X:0>2}",
                .{ name, bin, hi | lo, addr, self.bus.cpu_read_u8(addr) },
            ) catch {};
        }
        instruction(self, addr);
    }

    fn stack_pop_u8(self: *Cpu) u8 {
        self.reg.sp +%= 1;
        return self.bus.cpu_read_u8(Registers.STACK_BASE +% self.reg.sp);
    }

    fn stack_push_u8(self: *Cpu, data: u8) void {
        self.bus.cpu_write_u8(Registers.STACK_BASE +% self.reg.sp, data);
        self.reg.sp -%= 1;
    }

    fn stack_push_u16(self: *Cpu, data: u16) void {
        self.stack_push_u8(@truncate(data >> 8));
        self.stack_push_u8(@truncate(data & 0x00FF));
    }

    fn stack_pop_u16(self: *Cpu) u16 {
        const lo: u16 = self.stack_pop_u8();
        const hi: u16 = self.stack_pop_u8();
        return (hi << 8) | lo;
    }

    fn update_zero_negative_flags(self: *Cpu, val: u8) void {
        self.flags.zero = val == 0;
        self.flags.negative = val & 0x80 != 0;
    }

    fn sta(self: *Cpu, addr: u16) void {
        self.bus.cpu_write_u8(addr, self.reg.a);
    }

    fn stx(self: *Cpu, addr: u16) void {
        self.bus.cpu_write_u8(addr, self.reg.x);
    }

    fn sty(self: *Cpu, addr: u16) void {
        self.bus.cpu_write_u8(addr, self.reg.y);
    }

    fn lda(self: *Cpu, addr: u16) void {
        self.reg.a = self.bus.cpu_read_u8(addr);
        update_zero_negative_flags(self, self.reg.a);
    }

    fn ldx(self: *Cpu, addr: u16) void {
        self.reg.x = self.bus.cpu_read_u8(addr);
        update_zero_negative_flags(self, self.reg.x);
    }

    fn ldy(self: *Cpu, addr: u16) void {
        self.reg.y = self.bus.cpu_read_u8(addr);
        update_zero_negative_flags(self, self.reg.y);
    }

    fn acc(self: *Cpu, val: u8) void {
        const sum: u16 = @as(u16, self.reg.a) +%
            @as(u16, val) +% @as(u16, @intFromBool(self.flags.carry));
        self.flags.carry = sum > 0x00FF;
        self.flags.overflow = (sum ^ self.reg.a) & (sum ^ val) & 0x80 != 0;
        self.reg.a = @truncate(sum);
        update_zero_negative_flags(self, self.reg.a);
    }

    fn sbc(self: *Cpu, addr: u16) void {
        const val: i8 = @bitCast(self.bus.cpu_read_u8(addr));
        self.acc(@bitCast(-val -% 1));
    }

    fn adc(self: *Cpu, addr: u16) void {
        self.acc(self.bus.cpu_read_u8(addr));
    }

    fn op_and(self: *Cpu, addr: u16) void {
        self.reg.a &= self.bus.cpu_read_u8(addr);
        self.update_zero_negative_flags(self.reg.a);
    }

    fn ora(self: *Cpu, addr: u16) void {
        self.reg.a |= self.bus.cpu_read_u8(addr);
        self.update_zero_negative_flags(self.reg.a);
    }

    fn asl(self: *Cpu, val: u8) u8 {
        self.flags.carry = val & 0x80 != 0;
        const result: u8 = val << 1;
        self.update_zero_negative_flags(result);
        return result;
    }

    fn asl_acc(self: *Cpu) void {
        self.reg.a = self.asl(self.reg.a);
    }

    fn asl_addr(self: *Cpu, addr: u16) u8 {
        const data: u8 = self.asl(self.bus.cpu_read_u8(addr));
        self.bus.cpu_write_u8(addr, data);
        return data;
    }

    fn lsr(self: *Cpu, val: u8) u8 {
        self.flags.carry = val & 0x01 != 0;
        const result: u8 = val >> 1;
        self.update_zero_negative_flags(result);
        return result;
    }

    fn lsr_acc(self: *Cpu) void {
        self.reg.a = self.lsr(self.reg.a);
    }

    fn lsr_addr(self: *Cpu, addr: u16) u8 {
        const data: u8 = self.lsr(self.bus.cpu_read_u8(addr));
        self.bus.cpu_write_u8(addr, data);
        return data;
    }

    fn rol(self: *Cpu, val: u8) u8 {
        const carry_in: bool = self.flags.carry;
        self.flags.carry = val & 0x80 != 0;
        const result: u8 = val << 1 | @as(u8, @intFromBool(carry_in));
        self.update_zero_negative_flags(result);
        return result;
    }

    fn rol_acc(self: *Cpu) void {
        self.reg.a = self.rol(self.reg.a);
    }

    fn rol_addr(self: *Cpu, addr: u16) u8 {
        const data: u8 = self.rol(self.bus.cpu_read_u8(addr));
        self.bus.cpu_write_u8(addr, data);
        return data;
    }

    fn ror(self: *Cpu, val: u8) u8 {
        const carry_in: bool = self.flags.carry;
        self.flags.carry = val & 0x01 != 0;
        const result: u8 = val >> 1 | (@as(u8, @intFromBool(carry_in)) << 7);
        self.update_zero_negative_flags(result);
        return result;
    }

    fn ror_acc(self: *Cpu) void {
        self.reg.a = self.ror(self.reg.a);
    }

    fn ror_addr(self: *Cpu, addr: u16) u8 {
        const data: u8 = self.ror(self.bus.cpu_read_u8(addr));
        self.bus.cpu_write_u8(addr, data);
        return data;
    }

    fn branch_relative(self: *Cpu, cond: bool) void {
        const offset: i8 = @bitCast(self.bus.cpu_read_u8(self.pc_consume(1)));
        if (cond) {
            self.reg.pc = @bitCast(@as(i16, @bitCast(self.reg.pc)) +% offset);
        }
    }

    fn bit(self: *Cpu, addr: u16) void {
        const test_val: u8 = self.bus.cpu_read_u8(addr);
        self.flags.zero = test_val & self.reg.a == 0;
        self.flags.overflow = test_val & (1 << 6) != 0;
        self.flags.negative = test_val & (1 << 7) != 0;
    }

    fn cmp(self: *Cpu, addr: u16) void {
        const val: u8 = self.bus.cpu_read_u8(addr);
        self.flags.carry = self.reg.a >= val;
        self.update_zero_negative_flags(self.reg.a -% val);
    }

    fn cpx(self: *Cpu, addr: u16) void {
        const val: u8 = self.bus.cpu_read_u8(addr);
        self.flags.carry = self.reg.x >= val;
        self.update_zero_negative_flags(self.reg.x -% val);
    }

    fn cpy(self: *Cpu, addr: u16) void {
        const val: u8 = self.bus.cpu_read_u8(addr);
        self.flags.carry = self.reg.y >= val;
        self.update_zero_negative_flags(self.reg.y -% val);
    }

    fn dec(self: *Cpu, addr: u16) void {
        const result: u8 = self.bus.cpu_read_u8(addr) -% 1;
        self.bus.cpu_write_u8(addr, result);
        self.update_zero_negative_flags(result);
    }

    fn eor(self: *Cpu, addr: u16) void {
        self.reg.a ^= self.bus.cpu_read_u8(addr);
        self.update_zero_negative_flags(self.reg.a);
    }

    fn inc(self: *Cpu, addr: u16) u8 {
        const result: u8 = self.bus.cpu_read_u8(addr) +% 1;
        self.bus.cpu_write_u8(addr, result);
        self.update_zero_negative_flags(result);
        return result;
    }

    fn dcp(self: *Cpu, addr: u16) void {
        const data = self.bus.cpu_read_u8(addr) -% 1;
        self.bus.cpu_write_u8(addr, data);
        if (data <= self.reg.a) {
            self.flags.carry = true;
        }
        self.update_zero_negative_flags(self.reg.a -% data);
    }

    fn rla(self: *Cpu, addr: u16) void {
        self.reg.a &= self.rol_addr(addr);
        self.update_zero_negative_flags(self.reg.a);
    }

    fn slo(self: *Cpu, addr: u16) void {
        self.reg.a |= self.asl_addr(addr);
        self.update_zero_negative_flags(self.reg.a);
    }

    fn sre(self: *Cpu, addr: u16) void {
        self.reg.a ^= self.lsr_addr(addr);
        self.update_zero_negative_flags(self.reg.a);
    }

    fn rra(self: *Cpu, addr: u16) void {
        self.acc(self.ror_addr(addr));
    }

    fn isb(self: *Cpu, addr: u16) void {
        const val: i8 = @bitCast(self.inc(addr));
        self.acc(@bitCast(-val -% 1));
    }

    fn lax(self: *Cpu, addr: u16) void {
        self.reg.a = self.bus.cpu_read_u8(addr);
        self.update_zero_negative_flags(self.reg.a);
        self.reg.x = self.reg.a;
    }

    fn sax(self: *Cpu, addr: u16) void {
        self.bus.cpu_write_u8(addr, self.reg.a & self.reg.x);
    }

    fn jmp(self: *Cpu, addr: u16) void {
        self.reg.pc = addr;
    }

    fn nop(_: *Cpu) void {}

    fn nop1(self: *Cpu) void {
        _ = self.pc_consume(1);
    }

    fn nop2(self: *Cpu) void {
        _ = self.pc_consume(2);
    }

    fn tax(self: *Cpu) void {
        self.reg.x = self.reg.a;
        update_zero_negative_flags(self, self.reg.x);
    }

    fn tay(self: *Cpu) void {
        self.reg.y = self.reg.a;
        update_zero_negative_flags(self, self.reg.y);
    }

    fn txa(self: *Cpu) void {
        self.reg.a = self.reg.x;
        self.update_zero_negative_flags(self.reg.a);
    }

    fn tya(self: *Cpu) void {
        self.reg.a = self.reg.y;
        self.update_zero_negative_flags(self.reg.a);
    }

    fn inx(self: *Cpu) void {
        self.reg.x +%= 1;
        update_zero_negative_flags(self, self.reg.x);
    }

    fn iny(self: *Cpu) void {
        self.reg.y +%= 1;
        update_zero_negative_flags(self, self.reg.y);
    }

    fn dex(self: *Cpu) void {
        self.reg.x -%= 1;
        self.update_zero_negative_flags(self.reg.x);
    }

    fn dey(self: *Cpu) void {
        self.reg.y -%= 1;
        self.update_zero_negative_flags(self.reg.y);
    }

    fn tsx(self: *Cpu) void {
        self.reg.x = self.reg.sp;
        self.update_zero_negative_flags(self.reg.x);
    }

    fn txs(self: *Cpu) void {
        self.reg.sp = self.reg.x;
    }

    fn pha(self: *Cpu) void {
        self.stack_push_u8(self.reg.a);
    }

    fn pla(self: *Cpu) void {
        self.reg.a = self.stack_pop_u8();
        self.update_zero_negative_flags(self.reg.a);
    }

    fn jsr(self: *Cpu, addr: u16) void {
        self.stack_push_u16(self.reg.pc +% 1);
        self.reg.pc = addr;
    }

    fn rts(self: *Cpu) void {
        self.reg.pc = self.stack_pop_u16() +% 1;
    }

    fn bcc(self: *Cpu) void {
        self.branch_relative(!self.flags.carry);
    }

    fn bcs(self: *Cpu) void {
        self.branch_relative(self.flags.carry);
    }

    fn beq(self: *Cpu) void {
        self.branch_relative(self.flags.zero);
    }

    fn bmi(self: *Cpu) void {
        self.branch_relative(self.flags.negative);
    }

    fn bne(self: *Cpu) void {
        self.branch_relative(!self.flags.zero);
    }

    fn bpl(self: *Cpu) void {
        self.branch_relative(!self.flags.negative);
    }

    fn bvc(self: *Cpu) void {
        self.branch_relative(!self.flags.overflow);
    }

    fn bvs(self: *Cpu) void {
        self.branch_relative(self.flags.overflow);
    }

    fn clc(self: *Cpu) void {
        self.flags.carry = false;
    }

    fn cli(self: *Cpu) void {
        self.flags.interrupt_disable = false;
    }

    fn clv(self: *Cpu) void {
        self.flags.overflow = false;
    }

    fn sec(self: *Cpu) void {
        self.flags.carry = true;
    }

    fn sed(self: *Cpu) void {
        self.flags.decimal_mode = true;
    }

    fn cld(self: *Cpu) void {
        self.flags.decimal_mode = false;
    }

    fn sei(self: *Cpu) void {
        self.flags.interrupt_disable = true;
    }

    fn php(self: *Cpu) void {
        var flags: Flags = self.flags;
        flags.break1 = true;
        flags.break2 = true;
        self.stack_push_u8(@bitCast(flags));
    }

    fn plp(self: *Cpu) void {
        self.flags = @bitCast(self.stack_pop_u8());
        self.flags.break1 = false;
        self.flags.break2 = true;
    }

    fn rti(self: *Cpu) void {
        self.flags = @bitCast(self.stack_pop_u8());
        self.flags.break1 = false;
        self.flags.break2 = true;
        self.reg.pc = self.stack_pop_u16();
    }

    fn alr(self: *Cpu, addr: u16) void {
        self.reg.a &= self.bus.cpu_read_u8(addr);
        self.update_zero_negative_flags(self.reg.a);
        self.lsr_acc();
    }

    fn anc(self: *Cpu, addr: u16) void {
        self.reg.a &= self.bus.cpu_read_u8(addr);
        self.update_zero_negative_flags(self.reg.a);
        self.flags.carry = self.flags.negative;
    }

    fn axs(self: *Cpu, addr: u16) void {
        const data: u8 = self.bus.cpu_read_u8(addr);
        const x_and_a: u8 = self.reg.x & self.reg.a;
        const result: u8 = x_and_a -% data;
        if (data <= x_and_a) {
            self.flags.carry = true;
        }
        self.update_zero_negative_flags(result);
        self.reg.x = result;
    }

    fn arr(self: *Cpu, addr: u16) void {
        const data: u8 = self.bus.cpu_read_u8(addr);
        self.reg.a &= data;
        self.ror_acc();
        const bit_5: bool = self.reg.a & (1 << 5) == 1;
        const bit_6: bool = self.reg.a & (1 << 6) == 1;
        self.flags.carry = bit_6;
        self.flags.overflow = bit_5 != bit_6;
        self.update_zero_negative_flags(self.reg.a);
    }

    pub fn exec(self: *Cpu, trace: if (dbg) *[128]u8 else void) bool {
        comptime var opcodes: [256]OpCode = undefined;
        opcodes[0x0A] = .{ .name = " ASL", .instruction = asl_acc, .memory = no_memory_a, .cycles = 2 };
        opcodes[0x06] = .{ .name = " ASL", .instruction = asl_addr, .memory = zero_page, .cycles = 5 };
        opcodes[0x0E] = .{ .name = " ASL", .instruction = asl_addr, .memory = absolute, .cycles = 6 };
        opcodes[0x16] = .{ .name = " ASL", .instruction = asl_addr, .memory = zero_page_x, .cycles = 6 };
        opcodes[0x1E] = .{ .name = " ASL", .instruction = asl_addr, .memory = absolute_x, .cycles = 7 };
        opcodes[0x4A] = .{ .name = " LSR", .instruction = lsr_acc, .memory = no_memory_a, .cycles = 2 };
        opcodes[0x46] = .{ .name = " LSR", .instruction = lsr_addr, .memory = zero_page, .cycles = 5 };
        opcodes[0x56] = .{ .name = " LSR", .instruction = lsr_addr, .memory = zero_page_x, .cycles = 6 };
        opcodes[0x4E] = .{ .name = " LSR", .instruction = lsr_addr, .memory = absolute, .cycles = 6 };
        opcodes[0x5E] = .{ .name = " LSR", .instruction = lsr_addr, .memory = absolute_x, .cycles = 7 };
        opcodes[0x2A] = .{ .name = " ROL", .instruction = rol_acc, .memory = no_memory_a, .cycles = 2 };
        opcodes[0x26] = .{ .name = " ROL", .instruction = rol_addr, .memory = zero_page, .cycles = 5 };
        opcodes[0x36] = .{ .name = " ROL", .instruction = rol_addr, .memory = zero_page_x, .cycles = 6 };
        opcodes[0x2E] = .{ .name = " ROL", .instruction = rol_addr, .memory = absolute, .cycles = 6 };
        opcodes[0x3E] = .{ .name = " ROL", .instruction = rol_addr, .memory = absolute_x, .cycles = 7 };
        opcodes[0x6A] = .{ .name = " ROR", .instruction = ror_acc, .memory = no_memory_a, .cycles = 2 };
        opcodes[0x66] = .{ .name = " ROR", .instruction = ror_addr, .memory = zero_page, .cycles = 5 };
        opcodes[0x76] = .{ .name = " ROR", .instruction = ror_addr, .memory = zero_page_x, .cycles = 6 };
        opcodes[0x6E] = .{ .name = " ROR", .instruction = ror_addr, .memory = absolute, .cycles = 6 };
        opcodes[0x7E] = .{ .name = " ROR", .instruction = ror_addr, .memory = absolute_x, .cycles = 7 };
        opcodes[0x21] = .{ .name = " AND", .instruction = op_and, .memory = indirect_x, .cycles = 6 };
        opcodes[0x25] = .{ .name = " AND", .instruction = op_and, .memory = zero_page, .cycles = 3 };
        opcodes[0x29] = .{ .name = " AND", .instruction = op_and, .memory = immediate, .cycles = 2 };
        opcodes[0x2D] = .{ .name = " AND", .instruction = op_and, .memory = absolute, .cycles = 4 };
        opcodes[0x31] = .{ .name = " AND", .instruction = op_and, .memory = indirect_y, .cycles = 5 };
        opcodes[0x35] = .{ .name = " AND", .instruction = op_and, .memory = zero_page_x, .cycles = 4 };
        opcodes[0x39] = .{ .name = " AND", .instruction = op_and, .memory = absolute_y, .cycles = 4 };
        opcodes[0x3D] = .{ .name = " AND", .instruction = op_and, .memory = absolute_x, .cycles = 4 };
        opcodes[0x09] = .{ .name = " ORA", .instruction = ora, .memory = immediate, .cycles = 2 };
        opcodes[0x05] = .{ .name = " ORA", .instruction = ora, .memory = zero_page, .cycles = 3 };
        opcodes[0x15] = .{ .name = " ORA", .instruction = ora, .memory = zero_page_x, .cycles = 4 };
        opcodes[0x0D] = .{ .name = " ORA", .instruction = ora, .memory = absolute, .cycles = 4 };
        opcodes[0x1D] = .{ .name = " ORA", .instruction = ora, .memory = absolute_x, .cycles = 4 };
        opcodes[0x19] = .{ .name = " ORA", .instruction = ora, .memory = absolute_y, .cycles = 4 };
        opcodes[0x01] = .{ .name = " ORA", .instruction = ora, .memory = indirect_x, .cycles = 6 };
        opcodes[0x11] = .{ .name = " ORA", .instruction = ora, .memory = indirect_y, .cycles = 5 };
        opcodes[0x85] = .{ .name = " STA", .instruction = sta, .memory = zero_page, .cycles = 3 };
        opcodes[0x95] = .{ .name = " STA", .instruction = sta, .memory = zero_page_x, .cycles = 4 };
        opcodes[0x8D] = .{ .name = " STA", .instruction = sta, .memory = absolute, .cycles = 4 };
        opcodes[0x9D] = .{ .name = " STA", .instruction = sta, .memory = absolute_x, .cycles = 5 };
        opcodes[0x99] = .{ .name = " STA", .instruction = sta, .memory = absolute_y, .cycles = 5 };
        opcodes[0x81] = .{ .name = " STA", .instruction = sta, .memory = indirect_x, .cycles = 6 };
        opcodes[0x91] = .{ .name = " STA", .instruction = sta, .memory = indirect_y, .cycles = 6 };
        opcodes[0xA9] = .{ .name = " LDA", .instruction = lda, .memory = immediate, .cycles = 2 };
        opcodes[0xA5] = .{ .name = " LDA", .instruction = lda, .memory = zero_page, .cycles = 3 };
        opcodes[0xB5] = .{ .name = " LDA", .instruction = lda, .memory = zero_page_x, .cycles = 4 };
        opcodes[0xAD] = .{ .name = " LDA", .instruction = lda, .memory = absolute, .cycles = 4 };
        opcodes[0xBD] = .{ .name = " LDA", .instruction = lda, .memory = absolute_x, .cycles = 4 };
        opcodes[0xB9] = .{ .name = " LDA", .instruction = lda, .memory = absolute_y, .cycles = 4 };
        opcodes[0xA1] = .{ .name = " LDA", .instruction = lda, .memory = indirect_x, .cycles = 6 };
        opcodes[0xB1] = .{ .name = " LDA", .instruction = lda, .memory = indirect_y, .cycles = 5 };
        opcodes[0xA2] = .{ .name = " LDX", .instruction = ldx, .memory = immediate, .cycles = 2 };
        opcodes[0xA6] = .{ .name = " LDX", .instruction = ldx, .memory = zero_page, .cycles = 3 };
        opcodes[0xB6] = .{ .name = " LDX", .instruction = ldx, .memory = zero_page_y, .cycles = 4 };
        opcodes[0xAE] = .{ .name = " LDX", .instruction = ldx, .memory = absolute, .cycles = 4 };
        opcodes[0xBE] = .{ .name = " LDX", .instruction = ldx, .memory = absolute_y, .cycles = 4 };
        opcodes[0xA0] = .{ .name = " LDY", .instruction = ldy, .memory = immediate, .cycles = 2 };
        opcodes[0xA4] = .{ .name = " LDY", .instruction = ldy, .memory = zero_page, .cycles = 3 };
        opcodes[0xB4] = .{ .name = " LDY", .instruction = ldy, .memory = zero_page_x, .cycles = 4 };
        opcodes[0xAC] = .{ .name = " LDY", .instruction = ldy, .memory = absolute, .cycles = 4 };
        opcodes[0xBC] = .{ .name = " LDY", .instruction = ldy, .memory = absolute_x, .cycles = 4 };
        opcodes[0x86] = .{ .name = " STX", .instruction = stx, .memory = zero_page, .cycles = 3 };
        opcodes[0x96] = .{ .name = " STX", .instruction = stx, .memory = zero_page_y, .cycles = 4 };
        opcodes[0x8E] = .{ .name = " STX", .instruction = stx, .memory = absolute, .cycles = 4 };
        opcodes[0x84] = .{ .name = " STY", .instruction = sty, .memory = zero_page, .cycles = 3 };
        opcodes[0x94] = .{ .name = " STY", .instruction = sty, .memory = zero_page_x, .cycles = 4 };
        opcodes[0x8C] = .{ .name = " STY", .instruction = sty, .memory = absolute, .cycles = 4 };
        opcodes[0x61] = .{ .name = " ADC", .instruction = adc, .memory = indirect_x, .cycles = 6 };
        opcodes[0x65] = .{ .name = " ADC", .instruction = adc, .memory = zero_page, .cycles = 3 };
        opcodes[0x69] = .{ .name = " ADC", .instruction = adc, .memory = immediate, .cycles = 2 };
        opcodes[0x6D] = .{ .name = " ADC", .instruction = adc, .memory = absolute, .cycles = 4 };
        opcodes[0x71] = .{ .name = " ADC", .instruction = adc, .memory = indirect_y, .cycles = 5 };
        opcodes[0x75] = .{ .name = " ADC", .instruction = adc, .memory = zero_page_x, .cycles = 4 };
        opcodes[0x79] = .{ .name = " ADC", .instruction = adc, .memory = absolute_y, .cycles = 4 };
        opcodes[0x7D] = .{ .name = " ADC", .instruction = adc, .memory = absolute_x, .cycles = 4 };
        opcodes[0xEB] = .{ .name = "*SBC", .instruction = sbc, .memory = immediate, .cycles = 2 };
        opcodes[0xE1] = .{ .name = " SBC", .instruction = sbc, .memory = indirect_x, .cycles = 6 };
        opcodes[0xE5] = .{ .name = " SBC", .instruction = sbc, .memory = zero_page, .cycles = 3 };
        opcodes[0xE9] = .{ .name = " SBC", .instruction = sbc, .memory = immediate, .cycles = 2 };
        opcodes[0xED] = .{ .name = " SBC", .instruction = sbc, .memory = absolute, .cycles = 4 };
        opcodes[0xF1] = .{ .name = " SBC", .instruction = sbc, .memory = indirect_y, .cycles = 5 };
        opcodes[0xF5] = .{ .name = " SBC", .instruction = sbc, .memory = zero_page_x, .cycles = 4 };
        opcodes[0xF9] = .{ .name = " SBC", .instruction = sbc, .memory = absolute_y, .cycles = 4 };
        opcodes[0xFD] = .{ .name = " SBC", .instruction = sbc, .memory = absolute_x, .cycles = 4 };
        opcodes[0xAA] = .{ .name = " TAX", .instruction = tax, .memory = no_memory, .cycles = 2 };
        opcodes[0xA8] = .{ .name = " TAY", .instruction = tay, .memory = no_memory, .cycles = 2 };
        opcodes[0x8A] = .{ .name = " TXA", .instruction = txa, .memory = no_memory, .cycles = 2 };
        opcodes[0x98] = .{ .name = " TYA", .instruction = tya, .memory = no_memory, .cycles = 2 };
        opcodes[0xE8] = .{ .name = " INX", .instruction = inx, .memory = no_memory, .cycles = 2 };
        opcodes[0xC8] = .{ .name = " INY", .instruction = iny, .memory = no_memory, .cycles = 2 };
        opcodes[0xCA] = .{ .name = " DEX", .instruction = dex, .memory = no_memory, .cycles = 2 };
        opcodes[0x88] = .{ .name = " DEY", .instruction = dey, .memory = no_memory, .cycles = 2 };
        opcodes[0xE6] = .{ .name = " INC", .instruction = inc, .memory = zero_page, .cycles = 5 };
        opcodes[0xF6] = .{ .name = " INC", .instruction = inc, .memory = zero_page_x, .cycles = 6 };
        opcodes[0xEE] = .{ .name = " INC", .instruction = inc, .memory = absolute, .cycles = 6 };
        opcodes[0xFE] = .{ .name = " INC", .instruction = inc, .memory = absolute_x, .cycles = 7 };
        opcodes[0xC6] = .{ .name = " DEC", .instruction = dec, .memory = zero_page, .cycles = 5 };
        opcodes[0xD6] = .{ .name = " DEC", .instruction = dec, .memory = zero_page_x, .cycles = 6 };
        opcodes[0xCE] = .{ .name = " DEC", .instruction = dec, .memory = absolute, .cycles = 6 };
        opcodes[0xDE] = .{ .name = " DEC", .instruction = dec, .memory = absolute_x, .cycles = 7 };
        opcodes[0xC1] = .{ .name = " CMP", .instruction = cmp, .memory = indirect_x, .cycles = 6 };
        opcodes[0xC5] = .{ .name = " CMP", .instruction = cmp, .memory = zero_page, .cycles = 3 };
        opcodes[0xC9] = .{ .name = " CMP", .instruction = cmp, .memory = immediate, .cycles = 2 };
        opcodes[0xCD] = .{ .name = " CMP", .instruction = cmp, .memory = absolute, .cycles = 4 };
        opcodes[0xD1] = .{ .name = " CMP", .instruction = cmp, .memory = indirect_y, .cycles = 5 };
        opcodes[0xD5] = .{ .name = " CMP", .instruction = cmp, .memory = zero_page_x, .cycles = 4 };
        opcodes[0xD9] = .{ .name = " CMP", .instruction = cmp, .memory = absolute_y, .cycles = 4 };
        opcodes[0xDD] = .{ .name = " CMP", .instruction = cmp, .memory = absolute_x, .cycles = 4 };
        opcodes[0xE0] = .{ .name = " CPX", .instruction = cpx, .memory = immediate, .cycles = 2 };
        opcodes[0xEC] = .{ .name = " CPX", .instruction = cpx, .memory = absolute, .cycles = 4 };
        opcodes[0xE4] = .{ .name = " CPX", .instruction = cpx, .memory = zero_page, .cycles = 3 };
        opcodes[0xC0] = .{ .name = " CPY", .instruction = cpy, .memory = immediate, .cycles = 2 };
        opcodes[0xCC] = .{ .name = " CPY", .instruction = cpy, .memory = absolute, .cycles = 4 };
        opcodes[0xC4] = .{ .name = " CPY", .instruction = cpy, .memory = zero_page, .cycles = 3 };
        opcodes[0x45] = .{ .name = " EOR", .instruction = eor, .memory = zero_page, .cycles = 3 };
        opcodes[0x49] = .{ .name = " EOR", .instruction = eor, .memory = immediate, .cycles = 2 };
        opcodes[0x4D] = .{ .name = " EOR", .instruction = eor, .memory = absolute, .cycles = 4 };
        opcodes[0x5D] = .{ .name = " EOR", .instruction = eor, .memory = absolute_x, .cycles = 4 };
        opcodes[0x59] = .{ .name = " EOR", .instruction = eor, .memory = absolute_y, .cycles = 4 };
        opcodes[0x41] = .{ .name = " EOR", .instruction = eor, .memory = indirect_x, .cycles = 6 };
        opcodes[0x51] = .{ .name = " EOR", .instruction = eor, .memory = indirect_y, .cycles = 5 };
        opcodes[0x55] = .{ .name = " EOR", .instruction = eor, .memory = zero_page_x, .cycles = 4 };
        opcodes[0xBA] = .{ .name = " TSX", .instruction = tsx, .memory = no_memory, .cycles = 2 };
        opcodes[0x9A] = .{ .name = " TXS", .instruction = txs, .memory = no_memory, .cycles = 2 };
        opcodes[0x48] = .{ .name = " PHA", .instruction = pha, .memory = no_memory, .cycles = 3 };
        opcodes[0x68] = .{ .name = " PLA", .instruction = pla, .memory = no_memory, .cycles = 4 };
        opcodes[0x4C] = .{ .name = " JMP", .instruction = jmp, .memory = long_jump, .cycles = 3 };
        opcodes[0x6C] = .{ .name = " JMP", .instruction = jmp, .memory = indirect, .cycles = 5 };
        opcodes[0x20] = .{ .name = " JSR", .instruction = jsr, .memory = subroutine_jump, .cycles = 6 };
        opcodes[0x60] = .{ .name = " RTS", .instruction = rts, .memory = no_memory, .cycles = 6 };
        opcodes[0x90] = .{ .name = " BCC", .instruction = bcc, .memory = local_jump, .cycles = 2 };
        opcodes[0xB0] = .{ .name = " BCS", .instruction = bcs, .memory = local_jump, .cycles = 2 };
        opcodes[0xF0] = .{ .name = " BEQ", .instruction = beq, .memory = local_jump, .cycles = 2 };
        opcodes[0x30] = .{ .name = " BMI", .instruction = bmi, .memory = local_jump, .cycles = 2 };
        opcodes[0xD0] = .{ .name = " BNE", .instruction = bne, .memory = local_jump, .cycles = 2 };
        opcodes[0x10] = .{ .name = " BPL", .instruction = bpl, .memory = local_jump, .cycles = 2 };
        opcodes[0x50] = .{ .name = " BVC", .instruction = bvc, .memory = local_jump, .cycles = 2 };
        opcodes[0x70] = .{ .name = " BVS", .instruction = bvs, .memory = local_jump, .cycles = 2 };
        opcodes[0x24] = .{ .name = " BIT", .instruction = bit, .memory = zero_page, .cycles = 3 };
        opcodes[0x2C] = .{ .name = " BIT", .instruction = bit, .memory = absolute, .cycles = 4 };
        opcodes[0x18] = .{ .name = " CLC", .instruction = clc, .memory = no_memory, .cycles = 2 };
        opcodes[0x58] = .{ .name = " CLI", .instruction = cli, .memory = no_memory, .cycles = 2 };
        opcodes[0xB8] = .{ .name = " CLV", .instruction = clv, .memory = no_memory, .cycles = 2 };
        opcodes[0x38] = .{ .name = " SEC", .instruction = sec, .memory = no_memory, .cycles = 2 };
        opcodes[0xF8] = .{ .name = " SED", .instruction = sed, .memory = no_memory, .cycles = 2 };
        opcodes[0xD8] = .{ .name = " CLD", .instruction = cld, .memory = no_memory, .cycles = 2 };
        opcodes[0x78] = .{ .name = " SEI", .instruction = sei, .memory = no_memory, .cycles = 2 };
        opcodes[0x08] = .{ .name = " PHP", .instruction = php, .memory = no_memory, .cycles = 3 };
        opcodes[0x28] = .{ .name = " PLP", .instruction = plp, .memory = no_memory, .cycles = 4 };
        opcodes[0x40] = .{ .name = " RTI", .instruction = rti, .memory = no_memory, .cycles = 6 };
        opcodes[0x00] = .{ .name = " BRK", .instruction = nop, .memory = no_memory, .cycles = 7 };
        opcodes[0xEA] = .{ .name = " NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0xC3] = .{ .name = "*DCP", .instruction = dcp, .memory = indirect_x, .cycles = 8 };
        opcodes[0xD3] = .{ .name = "*DCP", .instruction = dcp, .memory = indirect_y, .cycles = 8 };
        opcodes[0xC7] = .{ .name = "*DCP", .instruction = dcp, .memory = zero_page, .cycles = 5 };
        opcodes[0xD7] = .{ .name = "*DCP", .instruction = dcp, .memory = zero_page_x, .cycles = 6 };
        opcodes[0xCF] = .{ .name = "*DCP", .instruction = dcp, .memory = absolute, .cycles = 6 };
        opcodes[0xDB] = .{ .name = "*DCP", .instruction = dcp, .memory = absolute_y, .cycles = 7 };
        opcodes[0xDF] = .{ .name = "*DCP", .instruction = dcp, .memory = absolute_x, .cycles = 7 };
        opcodes[0x27] = .{ .name = "*RLA", .instruction = rla, .memory = zero_page, .cycles = 5 };
        opcodes[0x37] = .{ .name = "*RLA", .instruction = rla, .memory = zero_page_x, .cycles = 6 };
        opcodes[0x23] = .{ .name = "*RLA", .instruction = rla, .memory = indirect_x, .cycles = 8 };
        opcodes[0x33] = .{ .name = "*RLA", .instruction = rla, .memory = indirect_y, .cycles = 8 };
        opcodes[0x2F] = .{ .name = "*RLA", .instruction = rla, .memory = absolute, .cycles = 6 };
        opcodes[0x3F] = .{ .name = "*RLA", .instruction = rla, .memory = absolute_x, .cycles = 7 };
        opcodes[0x3B] = .{ .name = "*RLA", .instruction = rla, .memory = absolute_y, .cycles = 7 };
        opcodes[0x07] = .{ .name = "*SLO", .instruction = slo, .memory = zero_page, .cycles = 5 };
        opcodes[0x17] = .{ .name = "*SLO", .instruction = slo, .memory = zero_page_x, .cycles = 6 };
        opcodes[0x03] = .{ .name = "*SLO", .instruction = slo, .memory = indirect_x, .cycles = 8 };
        opcodes[0x13] = .{ .name = "*SLO", .instruction = slo, .memory = indirect_y, .cycles = 8 };
        opcodes[0x0F] = .{ .name = "*SLO", .instruction = slo, .memory = absolute, .cycles = 6 };
        opcodes[0x1F] = .{ .name = "*SLO", .instruction = slo, .memory = absolute_x, .cycles = 7 };
        opcodes[0x1B] = .{ .name = "*SLO", .instruction = slo, .memory = absolute_y, .cycles = 7 };
        opcodes[0x47] = .{ .name = "*SRE", .instruction = sre, .memory = zero_page, .cycles = 5 };
        opcodes[0x57] = .{ .name = "*SRE", .instruction = sre, .memory = zero_page_x, .cycles = 6 };
        opcodes[0x43] = .{ .name = "*SRE", .instruction = sre, .memory = indirect_x, .cycles = 8 };
        opcodes[0x53] = .{ .name = "*SRE", .instruction = sre, .memory = indirect_y, .cycles = 8 };
        opcodes[0x4F] = .{ .name = "*SRE", .instruction = sre, .memory = absolute, .cycles = 6 };
        opcodes[0x5F] = .{ .name = "*SRE", .instruction = sre, .memory = absolute_x, .cycles = 7 };
        opcodes[0x5B] = .{ .name = "*SRE", .instruction = sre, .memory = absolute_y, .cycles = 7 };
        opcodes[0x67] = .{ .name = "*RRA", .instruction = rra, .memory = zero_page, .cycles = 5 };
        opcodes[0x77] = .{ .name = "*RRA", .instruction = rra, .memory = zero_page_x, .cycles = 6 };
        opcodes[0x63] = .{ .name = "*RRA", .instruction = rra, .memory = indirect_x, .cycles = 8 };
        opcodes[0x73] = .{ .name = "*RRA", .instruction = rra, .memory = indirect_y, .cycles = 8 };
        opcodes[0x6F] = .{ .name = "*RRA", .instruction = rra, .memory = absolute, .cycles = 6 };
        opcodes[0x7B] = .{ .name = "*RRA", .instruction = rra, .memory = absolute_y, .cycles = 7 };
        opcodes[0x7F] = .{ .name = "*RRA", .instruction = rra, .memory = absolute_x, .cycles = 7 };
        opcodes[0xE7] = .{ .name = "*ISB", .instruction = isb, .memory = zero_page, .cycles = 5 };
        opcodes[0xF7] = .{ .name = "*ISB", .instruction = isb, .memory = zero_page_x, .cycles = 6 };
        opcodes[0xE3] = .{ .name = "*ISB", .instruction = isb, .memory = indirect_x, .cycles = 8 };
        opcodes[0xF3] = .{ .name = "*ISB", .instruction = isb, .memory = indirect_y, .cycles = 8 };
        opcodes[0xEF] = .{ .name = "*ISB", .instruction = isb, .memory = absolute, .cycles = 6 };
        opcodes[0xFB] = .{ .name = "*ISB", .instruction = isb, .memory = absolute_y, .cycles = 7 };
        opcodes[0xFF] = .{ .name = "*ISB", .instruction = isb, .memory = absolute_x, .cycles = 7 };
        opcodes[0xA7] = .{ .name = "*LAX", .instruction = lax, .memory = zero_page, .cycles = 3 };
        opcodes[0xB7] = .{ .name = "*LAX", .instruction = lax, .memory = zero_page_y, .cycles = 4 };
        opcodes[0xA3] = .{ .name = "*LAX", .instruction = lax, .memory = indirect_x, .cycles = 6 };
        opcodes[0xB3] = .{ .name = "*LAX", .instruction = lax, .memory = indirect_y, .cycles = 5 };
        opcodes[0xAF] = .{ .name = "*LAX", .instruction = lax, .memory = absolute, .cycles = 4 };
        opcodes[0xBF] = .{ .name = "*LAX", .instruction = lax, .memory = absolute_y, .cycles = 4 };
        opcodes[0x87] = .{ .name = "*SAX", .instruction = sax, .memory = zero_page, .cycles = 3 };
        opcodes[0x97] = .{ .name = "*SAX", .instruction = sax, .memory = zero_page_y, .cycles = 4 };
        opcodes[0x83] = .{ .name = "*SAX", .instruction = sax, .memory = indirect_x, .cycles = 6 };
        opcodes[0x8F] = .{ .name = "*SAX", .instruction = sax, .memory = absolute, .cycles = 4 };
        opcodes[0x4B] = .{ .name = "*ALR", .instruction = alr, .memory = immediate, .cycles = 2 };
        opcodes[0x0B] = .{ .name = "*ANC", .instruction = anc, .memory = immediate, .cycles = 2 };
        opcodes[0x2B] = .{ .name = "*ANC", .instruction = anc, .memory = immediate, .cycles = 2 };
        opcodes[0xCB] = .{ .name = "*AXS", .instruction = axs, .memory = immediate, .cycles = 2 };
        opcodes[0x6B] = .{ .name = "*ARR", .instruction = arr, .memory = immediate, .cycles = 2 };
        opcodes[0x02] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0x12] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0x22] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0x32] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0x42] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0x52] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0x62] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0x72] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0x92] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0xB2] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0xD2] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0xF2] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0x1A] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0x3A] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0x5A] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0x7A] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0xDA] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0xFA] = .{ .name = "*NOP", .instruction = nop, .memory = no_memory, .cycles = 2 };
        opcodes[0x04] = .{ .name = "*NOP", .instruction = nop1, .memory = no_memory, .cycles = 3 };
        opcodes[0x44] = .{ .name = "*NOP", .instruction = nop1, .memory = no_memory, .cycles = 3 };
        opcodes[0x64] = .{ .name = "*NOP", .instruction = nop1, .memory = no_memory, .cycles = 3 };
        opcodes[0x14] = .{ .name = "*NOP", .instruction = nop1, .memory = no_memory, .cycles = 4 };
        opcodes[0x34] = .{ .name = "*NOP", .instruction = nop1, .memory = no_memory, .cycles = 4 };
        opcodes[0x54] = .{ .name = "*NOP", .instruction = nop1, .memory = no_memory, .cycles = 4 };
        opcodes[0x74] = .{ .name = "*NOP", .instruction = nop1, .memory = no_memory, .cycles = 4 };
        opcodes[0xD4] = .{ .name = "*NOP", .instruction = nop1, .memory = no_memory, .cycles = 4 };
        opcodes[0xF4] = .{ .name = "*NOP", .instruction = nop1, .memory = no_memory, .cycles = 4 };
        opcodes[0x80] = .{ .name = "*NOP", .instruction = nop1, .memory = no_memory, .cycles = 2 };
        opcodes[0x82] = .{ .name = "*NOP", .instruction = nop1, .memory = no_memory, .cycles = 2 };
        opcodes[0x89] = .{ .name = "*NOP", .instruction = nop1, .memory = no_memory, .cycles = 2 };
        opcodes[0xC2] = .{ .name = "*NOP", .instruction = nop1, .memory = no_memory, .cycles = 2 };
        opcodes[0xE2] = .{ .name = "*NOP", .instruction = nop1, .memory = no_memory, .cycles = 2 };
        opcodes[0x0C] = .{ .name = "*NOP", .instruction = nop2, .memory = no_memory, .cycles = 4 };
        opcodes[0x1C] = .{ .name = "*NOP", .instruction = nop2, .memory = no_memory, .cycles = 4 };
        opcodes[0x3C] = .{ .name = "*NOP", .instruction = nop2, .memory = no_memory, .cycles = 4 };
        opcodes[0x5C] = .{ .name = "*NOP", .instruction = nop2, .memory = no_memory, .cycles = 4 };
        opcodes[0x7C] = .{ .name = "*NOP", .instruction = nop2, .memory = no_memory, .cycles = 4 };
        opcodes[0xDC] = .{ .name = "*NOP", .instruction = nop2, .memory = no_memory, .cycles = 4 };
        opcodes[0xFC] = .{ .name = "*NOP", .instruction = nop2, .memory = no_memory, .cycles = 4 };
        // these are unstable af
        opcodes[0xAB] = .{ .name = "*ERR", .instruction = nop, .memory = no_memory, .cycles = 0 };
        opcodes[0x8B] = .{ .name = "*ERR", .instruction = nop, .memory = no_memory, .cycles = 0 };
        opcodes[0xBB] = .{ .name = "*ERR", .instruction = nop, .memory = no_memory, .cycles = 0 };
        opcodes[0x9B] = .{ .name = "*ERR", .instruction = nop, .memory = no_memory, .cycles = 0 };
        opcodes[0x93] = .{ .name = "*ERR", .instruction = nop, .memory = no_memory, .cycles = 0 };
        opcodes[0x9F] = .{ .name = "*ERR", .instruction = nop, .memory = no_memory, .cycles = 0 };
        opcodes[0x9E] = .{ .name = "*ERR", .instruction = nop, .memory = no_memory, .cycles = 0 };
        opcodes[0x9C] = .{ .name = "*ERR", .instruction = nop, .memory = no_memory, .cycles = 0 };

        const op_pc: u16 = self.pc_consume(1);
        const opcode: u8 = self.bus.cpu_read_u8(op_pc);

        var tmp: if (dbg) [25]u8 else void = undefined;
        if (dbg) {
            self.opcode = opcode;
            @memset(trace, ' ');
            @memset(&self.binary, ' ');
            @memset(&self.assembly, ' ');
            @memset(&tmp, 0);
            _ = std.fmt.bufPrint(
                &tmp,
                "A:{X:0>2} X:{X:0>2} Y:{X:0>2} P:{X:0>2} SP:{X:0>2}",
                .{
                    self.reg.a,
                    self.reg.x,
                    self.reg.y,
                    @as(u8, @bitCast(self.flags)),
                    self.reg.sp,
                },
            ) catch {};
        }

        const op: OpCode = opcodes[opcode];
        @as(
            *const fn (*Cpu, *const anyopaque, *const [4:0]u8) void,
            @ptrCast(op.memory),
        )(self, op.instruction, op.name);
        self.cycles += op.cycles;

        if (dbg) {
            _ = std.fmt.bufPrint(
                trace,
                "{X:0>4}  {s: <8} {s: <32} {s} PPU:TODO CYC:{}",
                .{ op_pc, self.binary, self.assembly, tmp, self.cycles },
            ) catch {};
        }

        return opcode != 0x00;
    }

    pub fn reset(self: *Cpu) void {
        self.reg = Registers.init();
        self.flags = Flags.init();
        self.reg.pc = self.bus.cpu_read_u16(0xFFFC);
        self.reg.pc = 0xC000; // force automated mode in nestest.nes
    }
};
