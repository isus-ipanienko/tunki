const std = @import("std");
const builtin = @import("builtin");
const dbg = builtin.mode == std.builtin.OptimizeMode.Debug;

const Bus = @import("bus.zig").Bus;

pub const Op = enum(u8) {
    BRK = 0x00,
    ORA_IX = 0x01,
    NOP_7 = 0x02,
    SLO_IX = 0x03,
    NOP_ZP_0 = 0x04,
    ORA_ZP = 0x05,
    ASL_ZP = 0x06,
    SLO_ZP = 0x07,
    PHP = 0x08,
    ORA_I = 0x09,
    ASL = 0x0A,
    ANC0 = 0x0B,
    NOP_A = 0x0C,
    ORA_A = 0x0D,
    ASL_A = 0x0E,
    SLO_A = 0x0F,
    BPL = 0x10,
    ORA_IY = 0x11,
    NOP_8 = 0x12,
    SLO_IY = 0x13,
    NOP_ZPX_0 = 0x14,
    ORA_ZPX = 0x15,
    ASL_ZPX = 0x16,
    SLO_ZPX = 0x17,
    CLC = 0x18,
    ORA_AY = 0x19,
    NOP_1 = 0x1A,
    SLO_AY = 0x1B,
    NOP_AX_0 = 0x1C,
    ORA_AX = 0x1D,
    ASL_AX = 0x1E,
    SLO_AX = 0x1F,
    JSR = 0x20,
    AND_IX = 0x21,
    NOP_9 = 0x22,
    RLA_IX = 0x23,
    BIT_ZP = 0x24,
    AND_ZP = 0x25,
    ROL_ZP = 0x26,
    RLA_ZP = 0x27,
    PLP = 0x28,
    AND_I = 0x29,
    ROL = 0x2A,
    ANC1 = 0x2B,
    BIT_A = 0x2C,
    AND_A = 0x2D,
    ROL_A = 0x2E,
    RLA_A = 0x2F,
    BMI = 0x30,
    AND_IY = 0x31,
    NOP_10 = 0x32,
    RLA_IY = 0x33,
    NOP_ZPX_1 = 0x34,
    AND_ZPX = 0x35,
    ROL_ZPX = 0x36,
    RLA_ZPX = 0x37,
    SEC = 0x38,
    AND_AY = 0x39,
    NOP_2 = 0x3A,
    RLA_AY = 0x3B,
    NOP_AX_1 = 0x3C,
    AND_AX = 0x3D,
    ROL_AX = 0x3E,
    RLA_AX = 0x3F,
    RTI = 0x40,
    EOR_IX = 0x41,
    NOP_11 = 0x42,
    SRE_IX = 0x43,
    NOP_ZP_1 = 0x44,
    EOR_ZP = 0x45,
    LSR_ZP = 0x46,
    SRE_ZP = 0x47,
    PHA = 0x48,
    EOR_I = 0x49,
    LSR = 0x4A,
    ALR = 0x4B,
    JMP_A = 0x4C,
    EOR_A = 0x4D,
    LSR_A = 0x4E,
    SRE_A = 0x4F,
    BVC = 0x50,
    EOR_IY = 0x51,
    NOP_12 = 0x52,
    SRE_IY = 0x53,
    NOP_ZPX_2 = 0x54,
    EOR_ZPX = 0x55,
    LSR_ZPX = 0x56,
    SRE_ZPX = 0x57,
    CLI = 0x58,
    EOR_AY = 0x59,
    NOP_3 = 0x5A,
    SRE_AY = 0x5B,
    NOP_AX_2 = 0x5C,
    EOR_AX = 0x5D,
    LSR_AX = 0x5E,
    SRE_AX = 0x5F,
    RTS = 0x60,
    ADC_IX = 0x61,
    NOP_13 = 0x62,
    RRA_IX = 0x63,
    NOP_ZP_2 = 0x64,
    ADC_ZP = 0x65,
    ROR_ZP = 0x66,
    RRA_ZP = 0x67,
    PLA = 0x68,
    ADC_I = 0x69,
    ROR = 0x6A,
    ARR = 0x6B,
    JMP_I = 0x6C,
    ADC_A = 0x6D,
    ROR_A = 0x6E,
    RRA_A = 0x6F,
    BVS = 0x70,
    ADC_IY = 0x71,
    NOP_14 = 0x72,
    RRA_IY = 0x73,
    NOP_ZPX_3 = 0x74,
    ADC_ZPX = 0x75,
    ROR_ZPX = 0x76,
    RRA_ZPX = 0x77,
    SEI = 0x78,
    ADC_AY = 0x79,
    NOP_4 = 0x7A,
    RRA_AY = 0x7B,
    NOP_AX_3 = 0x7C,
    ADC_AX = 0x7D,
    ROR_AX = 0x7E,
    RRA_AX = 0x7F,
    SKB0 = 0x80,
    STA_IX = 0x81,
    SKB1 = 0x82,
    SAX_IX = 0x83,
    STY_ZP = 0x84,
    STA_ZP = 0x85,
    STX_ZP = 0x86,
    SAX_ZP = 0x87,
    DEY = 0x88,
    SKB2 = 0x89,
    TXA = 0x8A,
    XAA = 0x8B,
    STY_A = 0x8C,
    STA_A = 0x8D,
    STX_A = 0x8E,
    SAX_A = 0x8F,
    BCC = 0x90,
    STA_IY = 0x91,
    NOP_15 = 0x92,
    AHX_IY = 0x93,
    STY_ZPX = 0x94,
    STA_ZPX = 0x95,
    STX_ZPY = 0x96,
    SAX_ZPY = 0x97,
    TYA = 0x98,
    STA_AY = 0x99,
    TXS = 0x9A,
    TAS = 0x9B,
    SHY = 0x9C,
    STA_AX = 0x9D,
    SHX = 0x9E,
    AHX_AY = 0x9F,
    LDY_I = 0xA0,
    LDA_IX = 0xA1,
    LDX_I = 0xA2,
    LAX_IX = 0xA3,
    LDY_ZP = 0xA4,
    LDA_ZP = 0xA5,
    LDX_ZP = 0xA6,
    LAX_ZP = 0xA7,
    TAY = 0xA8,
    LDA_I = 0xA9,
    TAX = 0xAA,
    LXA = 0xAB,
    LDY_A = 0xAC,
    LDA_A = 0xAD,
    LDX_A = 0xAE,
    LAX_A = 0xAF,
    BCS = 0xB0,
    LDA_IY = 0xB1,
    NOP_16 = 0xB2,
    LAX_IY = 0xB3,
    LDY_ZPX = 0xB4,
    LDA_ZPX = 0xB5,
    LDX_ZPY = 0xB6,
    LAX_ZPY = 0xB7,
    CLV = 0xB8,
    LDA_AY = 0xB9,
    TSX = 0xBA,
    LAS = 0xBB,
    LDY_AX = 0xBC,
    LDA_AX = 0xBD,
    LDX_AY = 0xBE,
    LAX_AY = 0xBF,
    CPY_I = 0xC0,
    CMP_IX = 0xC1,
    SKB3 = 0xC2,
    DCP_IX = 0xC3,
    CPY_ZP = 0xC4,
    CMP_ZP = 0xC5,
    DEC_ZP = 0xC6,
    DCP_ZP = 0xC7,
    INY = 0xC8,
    CMP_I = 0xC9,
    DEX = 0xCA,
    AXS = 0xCB,
    CPY_A = 0xCC,
    CMP_A = 0xCD,
    DEC_A = 0xCE,
    DCP_A = 0xCF,
    BNE = 0xD0,
    CMP_IY = 0xD1,
    NOP_17 = 0xD2,
    DCP_IY = 0xD3,
    NOP_ZPX_4 = 0xD4,
    CMP_ZPX = 0xD5,
    DEC_ZPX = 0xD6,
    DCP_ZPX = 0xD7,
    CLD = 0xD8,
    CMP_AY = 0xD9,
    NOP_5 = 0xDA,
    DCP_AY = 0xDB,
    NOP_AX_4 = 0xDC,
    CMP_AX = 0xDD,
    DEC_AX = 0xDE,
    DCP_AX = 0xDF,
    CPX_I = 0xE0,
    SBC_IX = 0xE1,
    SKB4 = 0xE2,
    ISB_IX = 0xE3,
    CPX_ZP = 0xE4,
    SBC_ZP = 0xE5,
    INC_ZP = 0xE6,
    ISB_ZP = 0xE7,
    INX = 0xE8,
    SBC_I = 0xE9,
    NOP = 0xEA,
    SBC_I_U = 0xEB,
    CPX_A = 0xEC,
    SBC_A = 0xED,
    INC_A = 0xEE,
    ISB_A = 0xEF,
    BEQ = 0xF0,
    SBC_IY = 0xF1,
    NOP_18 = 0xF2,
    ISB_IY = 0xF3,
    NOP_ZPX_5 = 0xF4,
    SBC_ZPX = 0xF5,
    INC_ZPX = 0xF6,
    ISB_ZPX = 0xF7,
    SED = 0xF8,
    SBC_AY = 0xF9,
    NOP_6 = 0xFA,
    ISB_AY = 0xFB,
    NOP_AX_5 = 0xFC,
    SBC_AX = 0xFD,
    INC_AX = 0xFE,
    ISB_AX = 0xFF,
};

const OpCycles = [_]u8{
    7,
    6,
    2,
    8,
    3,
    3,
    5,
    5,
    3,
    2,
    2,
    2,
    4,
    4,
    6,
    6,
    2,
    5,
    2,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7,
    6,
    6,
    2,
    8,
    3,
    3,
    5,
    5,
    4,
    2,
    2,
    2,
    4,
    4,
    6,
    6,
    2,
    5,
    2,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7,
    6,
    6,
    2,
    8,
    3,
    3,
    5,
    5,
    3,
    2,
    2,
    2,
    3,
    4,
    6,
    6,
    2,
    5,
    2,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7,
    6,
    6,
    2,
    8,
    3,
    3,
    5,
    5,
    4,
    2,
    2,
    2,
    5,
    4,
    6,
    6,
    2,
    5,
    2,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7,
    2,
    6,
    2,
    6,
    3,
    3,
    3,
    3,
    2,
    2,
    2,
    3,
    4,
    4,
    4,
    4,
    2,
    6,
    2,
    8,
    4,
    4,
    4,
    4,
    2,
    5,
    2,
    2,
    4,
    5,
    4,
    4,
    2,
    6,
    2,
    6,
    3,
    3,
    3,
    3,
    2,
    2,
    2,
    3,
    4,
    4,
    4,
    4,
    2,
    5,
    2,
    5,
    4,
    4,
    4,
    4,
    2,
    4,
    2,
    2,
    4,
    4,
    4,
    4,
    2,
    6,
    2,
    8,
    3,
    3,
    5,
    5,
    2,
    2,
    2,
    2,
    4,
    4,
    6,
    6,
    2,
    5,
    2,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7,
    2,
    6,
    2,
    8,
    3,
    3,
    5,
    5,
    2,
    2,
    2,
    2,
    4,
    4,
    6,
    6,
    2,
    5,
    2,
    8,
    4,
    4,
    6,
    6,
    2,
    4,
    2,
    7,
    4,
    4,
    7,
    7,
};

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
            .zero = true,
            .interrupt_disable = true,
            .decimal_mode = false,
            .break1 = false,
            .break2 = false,
            .overflow = false,
            .negative = false,
        };
    }
};

pub const Cpu = struct {
    reg: Registers,
    flags: Flags,
    cycles: u64,
    bus: *Bus,
    binary: if (dbg) [8]u8 else void,
    assembly: if (dbg) [32]u8 else void,
    opcode: if (dbg) Op else void,

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

    fn addr_immediate(self: *Cpu) u16 {
        return self.pc_consume(1);
    }

    fn addr_zero_page(self: *Cpu) u16 {
        return self.bus.cpu_read_u8(self.pc_consume(1));
    }

    fn addr_zero_page_x(self: *Cpu) u16 {
        return self.bus.cpu_read_u8(self.pc_consume(1)) +% self.reg.x;
    }

    fn addr_zero_page_y(self: *Cpu) u16 {
        return self.bus.cpu_read_u8(self.pc_consume(1)) +% self.reg.y;
    }

    fn addr_absolute(self: *Cpu) u16 {
        return self.bus.cpu_read_u16(self.pc_consume(2));
    }

    fn addr_absolute_x(self: *Cpu) u16 {
        return self.bus.cpu_read_u16(self.pc_consume(2)) +% @as(u16, self.reg.x);
    }

    fn addr_absolute_y(self: *Cpu) u16 {
        return self.bus.cpu_read_u16(self.pc_consume(2)) +% @as(u16, self.reg.y);
    }

    fn addr_indirect_x(self: *Cpu) u16 {
        const ptr: u8 = self.bus.cpu_read_u8(self.pc_consume(1)) +% self.reg.x;
        const hi: u16 = @as(u16, self.bus.cpu_read_u8(ptr +% 1)) << 8;
        const lo: u16 = @as(u16, self.bus.cpu_read_u8(ptr));
        return hi | lo;
    }

    fn addr_indirect_y(self: *Cpu) u16 {
        const ptr: u8 = self.bus.cpu_read_u8(self.pc_consume(1));
        const hi: u16 = @as(u16, self.bus.cpu_read_u8(ptr +% 1)) << 8;
        const lo: u16 = @as(u16, self.bus.cpu_read_u8(ptr));
        return (hi | lo) +% @as(u16, self.reg.y);
    }

    fn stack_pop_u8(self: *Cpu) u8 {
        self.reg.sp +%= 1;
        return self.bus.cpu_read_u8(Registers.STACK_BASE + self.reg.sp);
    }

    fn stack_push_u8(self: *Cpu, data: u8) void {
        self.bus.cpu_write_u8(Registers.STACK_BASE + self.reg.sp, data);
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
        self.flags.overflow = sum ^ (self.reg.a & val) & 0x80 != 0;
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
        self.reg.a +%= self.ror_addr(addr);
        self.update_zero_negative_flags(self.reg.a);
    }

    fn isb(self: *Cpu, addr: u16) void {
        self.reg.a -%= self.inc(addr);
        self.update_zero_negative_flags(self.reg.a);
    }

    fn lax(self: *Cpu, addr: u16) void {
        self.reg.a = self.inc(addr);
        self.update_zero_negative_flags(self.reg.a);
        self.reg.x = self.reg.a;
    }

    fn sax(self: *Cpu, addr: u16) void {
        self.bus.cpu_write_u8(addr, self.reg.a & self.reg.x);
    }

    fn jmp(self: *Cpu, addr: u16) void {
        self.reg.pc = addr;
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

    fn immediate(
        self: *Cpu,
        comptime instruction: anytype,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        const addr: u16 = self.addr_immediate();
        if (dbg) {
            const data: u8 = self.bus.cpu_read_u8(addr);
            self.make_binary(@intFromEnum(self.opcode), data, null);
            _ = std.fmt.bufPrint(
                &self.assembly,
                "{s} #${X:0>2}",
                .{ name, data },
            ) catch {};
        }
        _ = instruction(self, addr);
    }

    fn zero_page(
        self: *Cpu,
        comptime instruction: anytype,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        const addr: u16 = self.addr_zero_page();
        if (dbg) {
            const address: u8 = self.bus.cpu_read_u8(self.reg.pc - 1);
            self.make_binary(@intFromEnum(self.opcode), address, null);
            _ = std.fmt.bufPrint(
                &self.assembly,
                "{s} ${X:0>2} = {X:0>2}",
                .{ name, address, self.bus.cpu_read_u8(addr) },
            ) catch {};
        }
        _ = instruction(self, addr);
    }

    fn zero_page_x(
        self: *Cpu,
        comptime instruction: anytype,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        const addr: u16 = self.addr_zero_page_x();
        if (dbg) {
            const address: u8 = self.bus.cpu_read_u8(self.reg.pc - 1);
            self.make_binary(@intFromEnum(self.opcode), address, null);
            _ = std.fmt.bufPrint(
                &self.assembly,
                "{s} ${X:0>2},X @ {X:0>2} = {X:0>2}",
                .{ name, address, addr, self.bus.cpu_read_u8(addr) },
            ) catch {};
        }
        _ = instruction(self, addr);
    }

    fn absolute(
        self: *Cpu,
        comptime instruction: anytype,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        const addr: u16 = self.addr_absolute();
        if (dbg) {
            self.make_binary(@intFromEnum(self.opcode), @truncate(addr & 0xFF), @truncate(addr >> 8));
            _ = std.fmt.bufPrint(
                &self.assembly,
                "{s} ${X:0>4} = {X:0>2}",
                .{ name, addr, self.bus.cpu_read_u8(addr) },
            ) catch {};
        }
        _ = instruction(self, addr);
    }

    fn indirect(
        self: *Cpu,
        comptime instruction: anytype,
        name: if (dbg) *const [4:0]u8 else void,
    ) void {
        // indirect mode is bugged af
        const ref: u16 = self.addr_absolute();
        var deref: u16 = undefined;
        if (ref & 0x00FF == 0x00FF) {
            const lo: u16 = self.bus.cpu_read_u8(ref);
            const hi: u16 = self.bus.cpu_read_u8(ref & 0xFF00);
            deref = (hi << 8) | lo;
        } else {
            deref = self.bus.cpu_read_u16(ref);
        }
        if (dbg) {
            self.make_binary(@intFromEnum(self.opcode), @truncate(ref & 0xFF), @truncate(ref >> 8));
            _ = std.fmt.bufPrint(
                &self.assembly,
                "{s} (${X:0>4}) = {X:0>4}",
                .{ name, ref, deref },
            ) catch {};
        }
        _ = instruction(self, deref);
    }

    pub fn exec(self: *Cpu, trace: if (dbg) *[128]u8 else void) bool {
        const pc_saved: u16 = self.reg.pc;
        const opcode: Op = @enumFromInt(self.bus.cpu_read_u8(self.pc_consume(1)));
        var ret: bool = true;
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
        switch (opcode) {
            Op.ASL => {
                self.asl_acc();
            },
            Op.ASL_ZP => {
                self.zero_page(asl_addr, " ASL");
            },
            Op.ASL_A => {
                self.absolute(asl_addr, " ASL");
            },
            Op.ASL_ZPX => {
                self.zero_page_x(asl_addr, " ASL");
            },
            Op.ASL_AX => {
                _ = self.asl_addr(self.addr_absolute_x());
            },
            Op.LSR => {
                self.lsr_acc();
            },
            Op.LSR_ZP => {
                self.zero_page(lsr_addr, " LSR");
            },
            Op.LSR_ZPX => {
                self.zero_page_x(lsr_addr, " LSR");
            },
            Op.LSR_A => {
                self.absolute(lsr_addr, " LSR");
            },
            Op.LSR_AX => {
                _ = self.lsr_addr(self.addr_absolute_x());
            },
            Op.ROL => {
                self.rol_acc();
            },
            Op.ROL_ZP => {
                self.zero_page(rol_addr, " ROL");
            },
            Op.ROL_ZPX => {
                self.zero_page_x(rol_addr, " ROL");
            },
            Op.ROL_A => {
                self.absolute(rol_addr, " ROL");
            },
            Op.ROL_AX => {
                _ = self.rol_addr(self.addr_absolute_x());
            },
            Op.ROR => {
                self.ror_acc();
            },
            Op.ROR_ZP => {
                self.zero_page(ror_addr, " ROR");
            },
            Op.ROR_ZPX => {
                self.zero_page_x(ror_addr, " ROR");
            },
            Op.ROR_A => {
                self.absolute(ror_addr, " ROR");
            },
            Op.ROR_AX => {
                _ = self.ror_addr(self.addr_absolute_x());
            },
            Op.AND_IX => {
                self.op_and(self.addr_indirect_x());
            },
            Op.AND_ZP => {
                self.zero_page(op_and, " AND");
            },
            Op.AND_I => {
                self.immediate(op_and, " AND");
            },
            Op.AND_A => {
                self.absolute(op_and, " AND");
                self.op_and(self.addr_absolute());
            },
            Op.AND_IY => {
                self.op_and(self.addr_indirect_y());
            },
            Op.AND_ZPX => {
                self.zero_page_x(op_and, " AND");
            },
            Op.AND_AY => {
                self.op_and(self.addr_absolute_y());
            },
            Op.AND_AX => {
                self.op_and(self.addr_absolute_x());
            },
            Op.ORA_I => {
                self.immediate(ora, " ORA");
            },
            Op.ORA_ZP => {
                self.zero_page(ora, " ORA");
            },
            Op.ORA_ZPX => {
                self.zero_page_x(ora, " ORA");
            },
            Op.ORA_A => {
                self.absolute(ora, " ORA");
            },
            Op.ORA_AX => {
                self.ora(self.addr_absolute_x());
            },
            Op.ORA_AY => {
                self.ora(self.addr_absolute_y());
            },
            Op.ORA_IX => {
                self.ora(self.addr_indirect_x());
            },
            Op.ORA_IY => {
                self.ora(self.addr_indirect_y());
            },
            Op.STA_ZP => {
                self.zero_page(sta, " STA");
            },
            Op.STA_ZPX => {
                self.zero_page_x(sta, " STA");
            },
            Op.STA_A => {
                self.absolute(sta, " STA");
            },
            Op.STA_AX => {
                self.sta(self.addr_absolute_x());
            },
            Op.STA_AY => {
                self.sta(self.addr_absolute_y());
            },
            Op.STA_IX => {
                self.sta(self.addr_indirect_x());
            },
            Op.STA_IY => {
                self.sta(self.addr_indirect_y());
            },
            Op.LDA_I => {
                self.immediate(lda, " LDA");
            },
            Op.LDA_ZP => {
                self.zero_page(lda, " LDA");
            },
            Op.LDA_ZPX => {
                self.zero_page_x(lda, " LDA");
            },
            Op.LDA_A => {
                self.absolute(lda, " LDA");
            },
            Op.LDA_AX => {
                self.lda(self.addr_absolute_x());
            },
            Op.LDA_AY => {
                self.lda(self.addr_absolute_y());
            },
            Op.LDA_IX => {
                self.lda(self.addr_indirect_x());
            },
            Op.LDA_IY => {
                self.lda(self.addr_indirect_y());
            },
            Op.LDX_I => {
                self.immediate(ldx, " LDX");
            },
            Op.LDX_ZP => {
                self.zero_page(ldx, " LDX");
            },
            Op.LDX_ZPY => {
                self.ldx(self.addr_zero_page_y());
            },
            Op.LDX_A => {
                self.absolute(ldx, " LDX");
            },
            Op.LDX_AY => {
                self.ldx(self.addr_absolute_y());
            },
            Op.LDY_I => {
                self.immediate(ldy, " LDY");
            },
            Op.LDY_ZP => {
                self.zero_page(ldy, " LDY");
            },
            Op.LDY_ZPX => {
                self.zero_page_x(ldy, " LDY");
            },
            Op.LDY_A => {
                self.absolute(ldy, " LDY");
            },
            Op.LDY_AX => {
                self.ldy(self.addr_absolute_x());
            },
            Op.STX_ZP => {
                self.zero_page(stx, " STX");
            },
            Op.STX_ZPY => {
                self.stx(self.addr_zero_page_y());
            },
            Op.STX_A => {
                self.absolute(stx, " STX");
            },
            Op.STY_ZP => {
                self.zero_page(sty, " STY");
            },
            Op.STY_ZPX => {
                self.zero_page_x(sty, " STY");
            },
            Op.STY_A => {
                self.absolute(sty, " STY");
            },
            Op.ADC_IX => {
                self.adc(self.addr_indirect_x());
            },
            Op.ADC_ZP => {
                self.zero_page(adc, " ADC");
            },
            Op.ADC_I => {
                self.immediate(adc, " ADC");
            },
            Op.ADC_A => {
                self.absolute(adc, " ADC");
            },
            Op.ADC_IY => {
                self.adc(self.addr_indirect_y());
            },
            Op.ADC_ZPX => {
                self.zero_page_x(adc, " ADC");
            },
            Op.ADC_AY => {
                self.adc(self.addr_absolute_y());
            },
            Op.ADC_AX => {
                self.adc(self.addr_absolute_x());
            },
            Op.SBC_I_U => {
                self.immediate(sbc, "*SBC");
            },
            Op.SBC_IX => {
                self.sbc(self.addr_indirect_x());
            },
            Op.SBC_ZP => {
                self.zero_page(sbc, " SBC");
            },
            Op.SBC_I => {
                self.immediate(sbc, " SBC");
            },
            Op.SBC_A => {
                self.absolute(sbc, " SBC");
            },
            Op.SBC_IY => {
                self.sbc(self.addr_indirect_y());
            },
            Op.SBC_ZPX => {
                self.zero_page_x(sbc, " SBC");
            },
            Op.SBC_AY => {
                self.sbc(self.addr_absolute_y());
            },
            Op.SBC_AX => {
                self.sbc(self.addr_absolute_x());
            },
            Op.TAX => {
                self.reg.x = self.reg.a;
                update_zero_negative_flags(self, self.reg.x);
            },
            Op.TAY => {
                self.reg.y = self.reg.a;
                update_zero_negative_flags(self, self.reg.y);
            },
            Op.TXA => {
                self.reg.a = self.reg.x;
                self.update_zero_negative_flags(self.reg.a);
            },
            Op.TYA => {
                self.reg.a = self.reg.y;
                self.update_zero_negative_flags(self.reg.a);
            },
            Op.INX => {
                self.reg.x +%= 1;
                update_zero_negative_flags(self, self.reg.x);
            },
            Op.INY => {
                self.reg.y +%= 1;
                update_zero_negative_flags(self, self.reg.y);
            },
            Op.DEX => {
                self.reg.x -%= 1;
                self.update_zero_negative_flags(self.reg.x);
            },
            Op.DEY => {
                self.reg.y -%= 1;
                self.update_zero_negative_flags(self.reg.y);
            },
            Op.INC_ZP => {
                self.zero_page(inc, " INC");
            },
            Op.INC_ZPX => {
                self.zero_page_x(inc, " INC");
            },
            Op.INC_A => {
                self.absolute(inc, " INC");
            },
            Op.INC_AX => {
                _ = self.inc(self.addr_absolute_x());
            },
            Op.DEC_ZP => {
                self.zero_page(dec, " DEC");
            },
            Op.DEC_ZPX => {
                self.zero_page_x(dec, " DEC");
            },
            Op.DEC_A => {
                self.absolute(dec, " DEC");
            },
            Op.DEC_AX => {
                self.dec(self.addr_absolute_x());
            },
            Op.CMP_IX => {
                self.cmp(self.addr_indirect_x());
            },
            Op.CMP_ZP => {
                self.zero_page(cmp, " CMP");
            },
            Op.CMP_I => {
                self.immediate(cmp, " CMP");
            },
            Op.CMP_A => {
                self.absolute(cmp, " CMP");
            },
            Op.CMP_IY => {
                self.cmp(self.addr_indirect_y());
            },
            Op.CMP_ZPX => {
                self.zero_page_x(cmp, " CMP");
            },
            Op.CMP_AY => {
                self.cmp(self.addr_absolute_y());
            },
            Op.CMP_AX => {
                self.cmp(self.addr_absolute_x());
            },
            Op.CPX_I => {
                self.immediate(cpx, " CPX");
            },
            Op.CPX_A => {
                self.absolute(cpx, " CPX");
            },
            Op.CPX_ZP => {
                self.zero_page(cpx, " CPX");
            },
            Op.CPY_I => {
                self.immediate(cpy, " CPY");
            },
            Op.CPY_A => {
                self.absolute(cpy, " CPY");
            },
            Op.CPY_ZP => {
                self.zero_page(cpy, " CPY");
            },
            Op.EOR_ZP => {
                self.zero_page(eor, " EOR");
            },
            Op.EOR_I => {
                self.immediate(eor, " EOR");
            },
            Op.EOR_A => {
                self.absolute(eor, " EOR");
            },
            Op.EOR_AX => {
                self.eor(self.addr_absolute_x());
            },
            Op.EOR_AY => {
                self.eor(self.addr_absolute_y());
            },
            Op.EOR_IX => {
                self.eor(self.addr_indirect_x());
            },
            Op.EOR_IY => {
                self.eor(self.addr_indirect_y());
            },
            Op.EOR_ZPX => {
                self.zero_page_x(eor, " EOR");
            },
            Op.TSX => {
                self.reg.x = self.reg.sp;
                self.update_zero_negative_flags(self.reg.x);
            },
            Op.TXS => {
                self.reg.sp = self.reg.x;
            },
            Op.PHA => {
                self.stack_push_u8(self.reg.a);
            },
            Op.PLA => {
                self.reg.a = self.stack_pop_u8();
                self.update_zero_negative_flags(self.reg.a);
            },
            Op.JMP_A => {
                self.absolute(jmp, " JMP");
            },
            Op.JMP_I => {
                self.indirect(jmp, " JMP");
            },
            Op.JSR => {
                self.stack_push_u16(self.reg.pc +% 1);
                self.reg.pc = self.bus.cpu_read_u16(self.reg.pc);
            },
            Op.RTS => {
                self.reg.pc = self.stack_pop_u16() +% 1;
            },
            Op.BCC => {
                self.branch_relative(!self.flags.carry);
            },
            Op.BCS => {
                self.branch_relative(self.flags.carry);
            },
            Op.BEQ => {
                self.branch_relative(self.flags.zero);
            },
            Op.BMI => {
                self.branch_relative(self.flags.negative);
            },
            Op.BNE => {
                self.branch_relative(!self.flags.zero);
            },
            Op.BPL => {
                self.branch_relative(!self.flags.negative);
            },
            Op.BVC => {
                self.branch_relative(!self.flags.overflow);
            },
            Op.BVS => {
                self.branch_relative(self.flags.overflow);
            },
            Op.BIT_ZP => {
                self.zero_page(bit, " BIT");
            },
            Op.BIT_A => {
                self.absolute(bit, " BIT");
            },
            Op.CLC => {
                self.flags.carry = false;
            },
            Op.CLI => {
                self.flags.interrupt_disable = false;
            },
            Op.CLV => {
                self.flags.overflow = false;
            },
            Op.SEC => {
                self.flags.carry = true;
            },
            Op.SED => {
                self.flags.decimal_mode = true;
            },
            Op.CLD => {
                self.flags.decimal_mode = false;
            },
            Op.SEI => {
                self.flags.interrupt_disable = true;
            },
            Op.PHP => {
                var flags: Flags = self.flags;
                flags.break1 = true;
                flags.break2 = true;
                self.stack_push_u8(@bitCast(flags));
            },
            Op.PLP => {
                self.flags = @bitCast(self.stack_pop_u8());
                self.flags.break1 = false;
                self.flags.break2 = true;
            },
            Op.RTI => {
                self.flags = @bitCast(self.stack_pop_u8());
                self.flags.break1 = false;
                self.flags.break2 = true;
                self.reg.pc = self.stack_pop_u16();
            },
            Op.BRK => {
                ret = false;
            },
            // unofficial
            Op.DCP_IX => {
                self.dcp(self.addr_indirect_x());
            },
            Op.DCP_IY => {
                self.dcp(self.addr_indirect_y());
            },
            Op.DCP_ZP => {
                self.zero_page(dcp, "*DCP");
            },
            Op.DCP_ZPX => {
                self.zero_page_x(dcp, "*DCP");
            },
            Op.DCP_A => {
                self.absolute(dcp, "*DCP");
            },
            Op.DCP_AY => {
                self.dcp(self.addr_absolute_y());
            },
            Op.DCP_AX => {
                self.dcp(self.addr_absolute_x());
            },
            Op.RLA_ZP => {
                self.zero_page(rla, "*RLA");
            },
            Op.RLA_ZPX => {
                self.zero_page_x(rla, "*RLA");
            },
            Op.RLA_IX => {
                self.rla(self.addr_indirect_x());
            },
            Op.RLA_IY => {
                self.rla(self.addr_indirect_y());
            },
            Op.RLA_A => {
                self.absolute(rla, "*RLA");
            },
            Op.RLA_AX => {
                self.rla(self.addr_absolute_x());
            },
            Op.RLA_AY => {
                self.rla(self.addr_absolute_y());
            },
            Op.SLO_ZP => {
                self.zero_page(slo, "*SLO");
            },
            Op.SLO_ZPX => {
                self.zero_page_x(slo, "*SLO");
            },
            Op.SLO_IX => {
                self.slo(self.addr_indirect_x());
            },
            Op.SLO_IY => {
                self.slo(self.addr_indirect_y());
            },
            Op.SLO_A => {
                self.absolute(slo, "*SLO");
            },
            Op.SLO_AX => {
                self.slo(self.addr_absolute_x());
            },
            Op.SLO_AY => {
                self.slo(self.addr_absolute_y());
            },
            Op.SRE_ZP => {
                self.zero_page(sre, "*SRE");
            },
            Op.SRE_ZPX => {
                self.zero_page_x(sre, "*SRE");
            },
            Op.SRE_IX => {
                self.sre(self.addr_indirect_x());
            },
            Op.SRE_IY => {
                self.sre(self.addr_indirect_y());
            },
            Op.SRE_A => {
                self.absolute(sre, "*SRE");
            },
            Op.SRE_AX => {
                self.sre(self.addr_absolute_x());
            },
            Op.SRE_AY => {
                self.sre(self.addr_absolute_y());
            },
            Op.RRA_ZP => {
                self.zero_page(rra, "*RRA");
            },
            Op.RRA_ZPX => {
                self.zero_page_x(rra, "*RRA");
            },
            Op.RRA_IX => {
                self.rra(self.addr_indirect_x());
            },
            Op.RRA_IY => {
                self.rra(self.addr_indirect_y());
            },
            Op.RRA_A => {
                self.absolute(rra, "*RRA");
            },
            Op.RRA_AY => {
                self.rra(self.addr_absolute_y());
            },
            Op.RRA_AX => {
                self.rra(self.addr_absolute_x());
            },
            Op.ISB_ZP => {
                self.zero_page(isb, "*ISB");
            },
            Op.ISB_ZPX => {
                self.zero_page_x(isb, "*ISB");
            },
            Op.ISB_IX => {
                self.isb(self.addr_indirect_x());
            },
            Op.ISB_IY => {
                self.isb(self.addr_indirect_y());
            },
            Op.ISB_A => {
                self.absolute(isb, "*ISB");
            },
            Op.ISB_AY => {
                self.isb(self.addr_absolute_y());
            },
            Op.ISB_AX => {
                self.isb(self.addr_absolute_x());
            },
            Op.LAX_ZP => {
                self.zero_page(lax, "*LAX");
            },
            Op.LAX_ZPY => {
                self.lax(self.addr_zero_page_y());
            },
            Op.LAX_IX => {
                self.lax(self.addr_indirect_x());
            },
            Op.LAX_IY => {
                self.lax(self.addr_indirect_y());
            },
            Op.LAX_A => {
                self.absolute(lax, "*LAX");
            },
            Op.LAX_AY => {
                self.lax(self.addr_absolute_y());
            },
            Op.SAX_ZP => {
                self.zero_page(sax, "*SAX");
            },
            Op.SAX_ZPY => {
                self.sax(self.addr_zero_page_y());
            },
            Op.SAX_IX => {
                self.sax(self.addr_indirect_x());
            },
            Op.SAX_A => {
                self.absolute(sax, "*SAX");
            },
            Op.ALR => {
                self.reg.a &= self.bus.cpu_read_u8(self.addr_immediate());
                self.update_zero_negative_flags(self.reg.a);
                self.lsr_acc();
            },
            Op.ANC0, Op.ANC1 => {
                self.reg.a &= self.bus.cpu_read_u8(self.addr_immediate());
                self.update_zero_negative_flags(self.reg.a);
                self.flags.carry = self.flags.negative;
            },
            Op.AXS => {
                const data: u8 = self.bus.cpu_read_u8(self.addr_immediate());
                const x_and_a: u8 = self.reg.x & self.reg.a;
                const result: u8 = x_and_a -% data;
                if (data <= x_and_a) {
                    self.flags.carry = true;
                }
                self.update_zero_negative_flags(result);
                self.reg.x = result;
            },
            Op.ARR => {
                const data: u8 = self.bus.cpu_read_u8(self.addr_immediate());
                self.reg.a &= data;
                self.ror_acc();
                const bit_5: bool = self.reg.a & (1 << 5) == 1;
                const bit_6: bool = self.reg.a & (1 << 6) == 1;
                self.flags.carry = bit_6;
                self.flags.overflow = bit_5 != bit_6;
                self.update_zero_negative_flags(self.reg.a);
            },
            Op.NOP, Op.NOP_1, Op.NOP_2, Op.NOP_3, Op.NOP_4, Op.NOP_5, Op.NOP_6, Op.NOP_7, Op.NOP_8, Op.NOP_9, Op.NOP_10, Op.NOP_11, Op.NOP_12, Op.NOP_13, Op.NOP_14, Op.NOP_15, Op.NOP_16, Op.NOP_17, Op.NOP_18 => {},
            Op.NOP_ZP_0, Op.NOP_ZP_1, Op.NOP_ZP_2, Op.NOP_ZPX_0, Op.NOP_ZPX_1, Op.NOP_ZPX_2, Op.NOP_ZPX_3, Op.NOP_ZPX_4, Op.NOP_ZPX_5, Op.SKB0, Op.SKB1, Op.SKB2, Op.SKB3, Op.SKB4 => {
                _ = self.pc_consume(1);
            },
            Op.NOP_A, Op.NOP_AX_0, Op.NOP_AX_1, Op.NOP_AX_2, Op.NOP_AX_3, Op.NOP_AX_4, Op.NOP_AX_5 => {
                _ = self.pc_consume(2);
            },
            Op.LXA, Op.XAA, Op.LAS, Op.TAS, Op.AHX_IY, Op.AHX_AY, Op.SHX, Op.SHY => {
                // these are highly unstable and not used
                unreachable;
            },
        }
        self.cycles += OpCycles[@intFromEnum(opcode)];
        if (dbg) {
            _ = std.fmt.bufPrint(
                trace,
                "{X:0>4}  {s: <8} {s: <32} {s} PPU:TODO CYC:{}",
                .{ pc_saved, self.binary, self.assembly, tmp, self.cycles },
            ) catch {};
        }
        return ret;
    }

    pub fn reset(self: *Cpu) void {
        self.reg = Registers.init();
        self.flags = Flags.init();
        self.reg.pc = self.bus.cpu_read_u16(0xFFFC);
        self.reg.pc = 0xC000;
        std.debug.print("0x{X}", .{self.reg.pc});
    }
};