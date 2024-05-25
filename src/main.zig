const std = @import("std");

const Bus = struct {
    const CPU_MEM_SIZE: usize = 0x10000;
    const CPU_RAM_LO: u16 = 0x0000;
    const CPU_RAM_HI: u16 = 0x1FFF;
    const CPU_RAM_CHUNK: u16 = 0x7FF;
    const PRG_ROM_LO: u16 = 0x8000;
    const PRG_ROM_HI: u16 = 0xFFFF;
    const PRG_ROM_CHUNK: u16 = 0x4000;

    cpu_mem: [CPU_MEM_SIZE]u8,
    prg_rom_mirror: u16,

    pub fn init() Bus {
        return Bus{
            .cpu_mem = [_]u8{0} ** CPU_MEM_SIZE,
            .prg_rom_mirror = PRG_ROM_LO + PRG_ROM_CHUNK,
        };
    }

    fn cpu_read_u8(self: Bus, addr: u16) u8 {
        // TODO: add logging
        return switch (addr) {
            CPU_RAM_LO...CPU_RAM_HI => self.cpu_mem[addr & CPU_RAM_CHUNK],
            PRG_ROM_LO...PRG_ROM_HI => {
                var a = addr;
                if (a >= self.prg_rom_mirror) {
                    a -= PRG_ROM_CHUNK;
                }
                return self.cpu_mem[a];
            },
            else => unreachable,
        };
    }

    fn cpu_write_u8(self: *Bus, addr: u16, data: u8) void {
        // TODO: add logging
        switch (addr) {
            CPU_RAM_LO...CPU_RAM_HI => self.cpu_mem[addr & CPU_RAM_CHUNK] = data,
            PRG_ROM_LO...PRG_ROM_HI => unreachable,
            else => unreachable,
        }
    }

    fn cpu_read_u16(self: Bus, addr: u16) u16 {
        const hi: u16 = @as(u16, self.cpu_read_u8(addr + 1)) << 8;
        const lo: u16 = self.cpu_read_u8(addr);
        return hi | lo;
    }

    fn cpu_write_u16(self: *Bus, addr: u16, data: u16) void {
        self.cpu_write_u8(addr, (data & 0xFF));
        self.cpu_write_u8(addr + 1, (data >> 8));
    }
};

const Op = enum(u8) {
    RET = 0x00,
    ORA_IX = 0x01,
    ORA_ZP = 0x05,
    ASL_ZP = 0x06,
    PHP = 0x08,
    ORA_I = 0x09,
    ASL = 0x0A,
    ORA_A = 0x0D,
    ASL_A = 0x0E,
    BPL = 0x10,
    ORA_IY = 0x11,
    ORA_ZPX = 0x15,
    ASL_ZPX = 0x16,
    CLC = 0x18,
    ORA_AY = 0x19,
    ORA_AX = 0x1D,
    ASL_AX = 0x1E,
    JSR = 0x20,
    AND_IX = 0x21,
    BIT_ZP = 0x24,
    AND_ZP = 0x25,
    PLP = 0x28,
    AND_I = 0x29,
    BIT_A = 0x2C,
    AND_A = 0x2D,
    BMI = 0x30,
    AND_IY = 0x31,
    AND_ZPX = 0x35,
    AND_AY = 0x39,
    AND_AX = 0x3D,
    EOR_IX = 0x41,
    EOR_ZP = 0x45,
    LSR_ZP = 0x46,
    PHA = 0x48,
    EOR_I = 0x49,
    LSR = 0x4A,
    JMP_A = 0x4C,
    EOR_A = 0x4D,
    LSR_A = 0x4E,
    BVC = 0x50,
    EOR_IY = 0x51,
    EOR_ZPX = 0x55,
    LSR_ZPX = 0x56,
    CLI = 0x58,
    EOR_AY = 0x59,
    EOR_AX = 0x5D,
    LSR_AX = 0x5E,
    RTS = 0x60,
    ADC_IX = 0x61,
    ADC_ZP = 0x65,
    PLA = 0x68,
    ADC_I = 0x69,
    JMP_I = 0x6C,
    ADC_A = 0x6D,
    BVS = 0x70,
    ADC_IY = 0x71,
    ADC_ZPX = 0x75,
    ADC_AY = 0x79,
    ADC_AX = 0x7D,
    STA_IX = 0x81,
    STA_ZP = 0x85,
    STX_ZP = 0x86,
    DEY = 0x88,
    STA_A = 0x8D,
    STX_A = 0x8E,
    BCC = 0x90,
    STA_IY = 0x91,
    STA_ZPX = 0x95,
    STX_ZPY = 0x96,
    STA_AX = 0x9D,
    STA_AY = 0x99,
    LDY_I = 0xA0,
    LDA_IX = 0xA1,
    LDX_I = 0xA2,
    LDY_ZP = 0xA4,
    LDA_ZP = 0xA5,
    LDX_ZP = 0xA6,
    LDA_I = 0xA9,
    TAX = 0xAA,
    LDY_A = 0xAC,
    LDA_A = 0xAD,
    LDX_A = 0xAE,
    BCS = 0xB0,
    LDA_IY = 0xB1,
    LDY_ZPX = 0xB4,
    LDA_ZPX = 0xB5,
    LDX_ZPY = 0xB6,
    CLV = 0xB8,
    LDA_AY = 0xB9,
    LDY_AX = 0xBC,
    LDA_AX = 0xBD,
    LDX_AY = 0xBE,
    CPY_I = 0xC0,
    CMP_IX = 0xC1,
    CPY_ZP = 0xC4,
    CMP_ZP = 0xC5,
    DEC_ZP = 0xC6,
    INY = 0xC8,
    CMP_I = 0xC9,
    DEX = 0xCA,
    CPY_A = 0xCC,
    CMP_A = 0xCD,
    DEC_A = 0xCE,
    BNE = 0xD0,
    CMP_IY = 0xD1,
    CMP_ZPX = 0xD5,
    DEC_ZPX = 0xD6,
    CMP_AY = 0xD9,
    CMP_AX = 0xDD,
    DEC_AX = 0xDE,
    CPX_I = 0xE0,
    SBC_IX = 0xE1,
    CPX_ZP = 0xE4,
    SBC_ZP = 0xE5,
    INX = 0xE8,
    SBC_I = 0xE9,
    NOP = 0xEA,
    CPX_A = 0xEC,
    SBC_A = 0xED,
    INC_ZP = 0xE6,
    INC_ZPX = 0xF6,
    INC_A = 0xEE,
    INC_AX = 0xFE,
    BEQ = 0xF0,
    SBC_IY = 0xF1,
    SBC_ZPX = 0xF5,
    SBC_AY = 0xF9,
    SBC_AX = 0xFD,
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
    padding: bool,
    interrupt_disable: bool,
    decimal_mode: bool,
    break_command: bool,
    overflow: bool,
    negative: bool,

    pub fn init() Flags {
        return Flags{
            .carry = false,
            .zero = true,
            .padding = false,
            .interrupt_disable = true,
            .decimal_mode = false,
            .break_command = false,
            .overflow = false,
            .negative = false,
        };
    }
};

const Cpu = struct {
    reg: Registers,
    flags: Flags,
    bus: *Bus,

    pub fn init(bus: *Bus) Cpu {
        return Cpu{
            .reg = Registers.init(),
            .flags = Flags.init(),
            .bus = bus,
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

    fn tax(self: *Cpu) void {
        self.reg.x = self.reg.a;
        update_zero_negative_flags(self, self.reg.x);
    }

    fn inx(self: *Cpu) void {
        self.reg.x +%= 1;
        update_zero_negative_flags(self, self.reg.x);
    }

    fn iny(self: *Cpu) void {
        self.reg.y +%= 1;
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

    fn asl_addr(self: *Cpu, addr: u16) void {
        self.bus.cpu_write_u8(addr, self.asl(self.bus.cpu_read_u8(addr)));
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

    fn lsr_addr(self: *Cpu, addr: u16) void {
        self.bus.cpu_write_u8(addr, self.lsr(self.bus.cpu_read_u8(addr)));
    }

    fn branch_relative(self: *Cpu, cond: bool) void {
        const offset: i8 = @bitCast(self.bus.cpu_read_u8(self.pc_consume(1)));
        if (cond) {
            self.reg.pc = @bitCast(@as(i16, @bitCast(self.reg.pc)) +% offset);
        }
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

    fn bne(self: *Cpu) void {
        self.branch_relative(!self.flags.zero);
    }

    fn bmi(self: *Cpu) void {
        self.branch_relative(self.flags.negative);
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

    fn dex(self: *Cpu) void {
        self.reg.x -%= 1;
        self.update_zero_negative_flags(self.reg.x);
    }

    fn dey(self: *Cpu) void {
        self.reg.y -%= 1;
        self.update_zero_negative_flags(self.reg.y);
    }

    fn eor(self: *Cpu, addr: u16) void {
        self.reg.a ^= self.bus.cpu_read_u8(addr);
        self.update_zero_negative_flags(self.reg.a);
    }

    fn inc(self: *Cpu, addr: u16) void {
        const result: u8 = self.bus.cpu_read_u8(addr) +% 1;
        self.bus.cpu_write_u8(addr, result);
        self.update_zero_negative_flags(result);
    }

    fn jmp(self: *Cpu, addr: u16) void {
        self.reg.pc = self.bus.cpu_read_u16(addr);
    }

    fn jmp_bugged(self: *Cpu, addr: u16) void {
        var ref: u16 = undefined;
        if (addr & 0x00FF == 0x00FF) {
            const lo: u16 = self.bus.cpu_read_u8(addr);
            const hi: u16 = self.bus.cpu_read_u8(addr & 0xFF00);
            ref = (hi << 8) | lo;
        } else {
            ref = self.bus.cpu_read_u16(addr);
        }
        self.reg.pc = self.bus.cpu_read_u16(ref);
    }

    fn jsr(self: *Cpu) void {
        self.stack_push_u16(self.reg.pc +% 1);
        self.reg.pc = self.bus.cpu_read_u16(self.reg.pc);
    }

    fn rts(self: *Cpu) void {
        self.reg.pc = self.stack_pop_u16() +% 1;
    }

    pub fn exec(self: *Cpu) void {
        var opcode: Op = undefined;
        while (true) {
            opcode = @enumFromInt(self.bus.cpu_read_u8(self.pc_consume(1)));
            switch (opcode) {
                Op.ASL_ZP => {
                    self.asl_addr(self.addr_zero_page());
                },
                Op.ASL => {
                    self.asl_acc();
                },
                Op.ASL_A => {
                    self.asl_addr(self.addr_absolute());
                },
                Op.ASL_ZPX => {
                    self.asl_addr(self.addr_zero_page_x());
                },
                Op.ASL_AX => {
                    self.asl_addr(self.addr_absolute_x());
                },
                Op.LSR => {
                    self.lsr_acc();
                },
                Op.LSR_ZP => {
                    self.lsr_addr(self.addr_zero_page());
                },
                Op.LSR_ZPX => {
                    self.lsr_addr(self.addr_zero_page_x());
                },
                Op.LSR_A => {
                    self.lsr_addr(self.addr_absolute());
                },
                Op.LSR_AX => {
                    self.lsr_addr(self.addr_absolute_x());
                },
                Op.AND_IX => {
                    self.op_and(self.addr_indirect_x());
                },
                Op.AND_ZP => {
                    self.op_and(self.addr_zero_page());
                },
                Op.AND_I => {
                    self.op_and(self.addr_immediate());
                },
                Op.AND_A => {
                    self.op_and(self.addr_absolute());
                },
                Op.AND_IY => {
                    self.op_and(self.addr_indirect_y());
                },
                Op.AND_ZPX => {
                    self.op_and(self.addr_zero_page_x());
                },
                Op.AND_AY => {
                    self.op_and(self.addr_absolute_y());
                },
                Op.AND_AX => {
                    self.op_and(self.addr_absolute_x());
                },
                Op.ORA_I => {
                    self.ora(self.addr_immediate());
                },
                Op.ORA_ZP => {
                    self.ora(self.addr_zero_page());
                },
                Op.ORA_ZPX => {
                    self.ora(self.addr_zero_page_x());
                },
                Op.ORA_A => {
                    self.ora(self.addr_absolute());
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
                    self.sta(self.addr_zero_page());
                },
                Op.STA_ZPX => {
                    self.sta(self.addr_zero_page_x());
                },
                Op.STA_A => {
                    self.sta(self.addr_absolute());
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
                    self.lda(self.addr_immediate());
                },
                Op.LDA_ZP => {
                    self.lda(self.addr_zero_page());
                },
                Op.LDA_ZPX => {
                    self.lda(self.addr_zero_page_x());
                },
                Op.LDA_A => {
                    self.lda(self.addr_absolute());
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
                    self.ldx(self.addr_immediate());
                },
                Op.LDX_ZP => {
                    self.ldx(self.addr_zero_page());
                },
                Op.LDX_ZPY => {
                    self.ldx(self.addr_zero_page_y());
                },
                Op.LDX_A => {
                    self.ldx(self.addr_absolute());
                },
                Op.LDX_AY => {
                    self.ldx(self.addr_absolute_y());
                },
                Op.LDY_I => {
                    self.ldy(self.addr_immediate());
                },
                Op.LDY_ZP => {
                    self.ldy(self.addr_zero_page());
                },
                Op.LDY_ZPX => {
                    self.ldy(self.addr_zero_page_x());
                },
                Op.LDY_A => {
                    self.ldy(self.addr_absolute());
                },
                Op.LDY_AX => {
                    self.ldy(self.addr_absolute_x());
                },
                Op.STX_ZP => {
                    self.stx(self.addr_zero_page());
                },
                Op.STX_ZPY => {
                    self.stx(self.addr_zero_page_y());
                },
                Op.STX_A => {
                    self.stx(self.addr_absolute());
                },
                Op.ADC_IX => {
                    self.adc(self.addr_indirect_x());
                },
                Op.ADC_ZP => {
                    self.adc(self.addr_zero_page());
                },
                Op.ADC_I => {
                    self.adc(self.addr_immediate());
                },
                Op.ADC_A => {
                    self.adc(self.addr_absolute());
                },
                Op.ADC_IY => {
                    self.adc(self.addr_indirect_y());
                },
                Op.ADC_ZPX => {
                    self.adc(self.addr_zero_page_x());
                },
                Op.ADC_AY => {
                    self.adc(self.addr_absolute_y());
                },
                Op.ADC_AX => {
                    self.adc(self.addr_absolute_x());
                },
                Op.SBC_IX => {
                    self.sbc(self.addr_indirect_x());
                },
                Op.SBC_ZP => {
                    self.sbc(self.addr_zero_page());
                },
                Op.SBC_I => {
                    self.sbc(self.addr_immediate());
                },
                Op.SBC_A => {
                    self.sbc(self.addr_absolute());
                },
                Op.SBC_IY => {
                    self.sbc(self.addr_indirect_y());
                },
                Op.SBC_ZPX => {
                    self.sbc(self.addr_zero_page_x());
                },
                Op.SBC_AY => {
                    self.sbc(self.addr_absolute_y());
                },
                Op.SBC_AX => {
                    self.sbc(self.addr_absolute_x());
                },
                Op.TAX => {
                    self.tax();
                },
                Op.INY => {
                    self.iny();
                },
                Op.INX => {
                    self.inx();
                },
                Op.DEX => {
                    self.dex();
                },
                Op.DEY => {
                    self.dey();
                },
                Op.DEC_ZP => {
                    self.dec(self.addr_zero_page());
                },
                Op.DEC_ZPX => {
                    self.dec(self.addr_zero_page_x());
                },
                Op.DEC_A => {
                    self.dec(self.addr_absolute());
                },
                Op.DEC_AX => {
                    self.dec(self.addr_absolute_x());
                },
                Op.CMP_IX => {
                    self.cmp(self.addr_indirect_x());
                },
                Op.CMP_ZP => {
                    self.cmp(self.addr_zero_page());
                },
                Op.CMP_I => {
                    self.cmp(self.addr_immediate());
                },
                Op.CMP_A => {
                    self.cmp(self.addr_absolute());
                },
                Op.CMP_IY => {
                    self.cmp(self.addr_indirect_y());
                },
                Op.CMP_ZPX => {
                    self.cmp(self.addr_zero_page_x());
                },
                Op.CMP_AY => {
                    self.cmp(self.addr_absolute_y());
                },
                Op.CMP_AX => {
                    self.cmp(self.addr_absolute_x());
                },
                Op.CPX_I => {
                    self.cpx(self.addr_immediate());
                },
                Op.CPX_A => {
                    self.cpx(self.addr_absolute());
                },
                Op.CPX_ZP => {
                    self.cpx(self.addr_zero_page());
                },
                Op.CPY_I => {
                    self.cpy(self.addr_immediate());
                },
                Op.CPY_A => {
                    self.cpy(self.addr_absolute());
                },
                Op.CPY_ZP => {
                    self.cpy(self.addr_zero_page());
                },
                Op.JMP_A => {
                    self.jmp(self.addr_absolute());
                },
                Op.JMP_I => {
                    self.jmp_bugged(self.addr_immediate());
                },
                Op.JSR => {
                    self.jsr();
                },
                Op.RTS => {
                    self.rts();
                },
                Op.BCC => {
                    self.bcc();
                },
                Op.BCS => {
                    self.bcs();
                },
                Op.BEQ => {
                    self.beq();
                },
                Op.BMI => {
                    self.bmi();
                },
                Op.BNE => {
                    self.bne();
                },
                Op.BPL => {
                    self.bpl();
                },
                Op.BVC => {
                    self.bvc();
                },
                Op.BVS => {
                    self.bvs();
                },
                Op.BIT_ZP => {
                    self.bit(self.addr_zero_page());
                },
                Op.BIT_A => {
                    self.bit(self.addr_absolute());
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
                Op.EOR_ZP => {
                    self.eor(self.addr_zero_page());
                },
                Op.EOR_I => {
                    self.eor(self.addr_immediate());
                },
                Op.EOR_A => {
                    self.eor(self.addr_absolute());
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
                    self.eor(self.addr_zero_page_x());
                },
                Op.INC_ZP => {
                    self.inc(self.addr_zero_page());
                },
                Op.INC_ZPX => {
                    self.inc(self.addr_zero_page_x());
                },
                Op.INC_A => {
                    self.inc(self.addr_absolute());
                },
                Op.INC_AX => {
                    self.inc(self.addr_absolute_x());
                },
                Op.PHA => {
                    self.stack_push_u8(self.reg.a);
                },
                Op.PHP => {
                    self.stack_push_u8(@bitCast(self.flags));
                },
                Op.PLA => {
                    self.reg.a = self.stack_pop_u8();
                    self.update_zero_negative_flags(self.reg.a);
                },
                Op.PLP => {
                    self.flags = @bitCast(self.stack_pop_u8());
                },
                Op.NOP => {},
                Op.RET => {
                    return;
                },
            }
        }
    }

    pub fn reset(self: *Cpu) void {
        self.reg = Registers.init();
        self.flags = Flags.init();
        self.reg.pc = self.bus.cpu_read_u16(0xFFFC);
    }

    pub fn insert(self: *Cpu, cartridge: [0x4000]u8) void {
        std.mem.copyForwards(u8, self.bus.cpu_mem[0x8000..0xC000], &cartridge);
        self.reset();
    }

    pub fn display(self: Cpu) void {
        std.debug.print("\n", .{});
        for (0.., self.bus.cpu_mem) |i, m| {
            if (m > 0) {
                std.debug.print("0x{X}: 0x{X}\n", .{ i, m });
            }
        }
    }
};

test "cpu" {
    var bus: Bus = Bus.init();
    var cpu: Cpu = Cpu.init(&bus);
    var cartridge: [0x4000]u8 = undefined;
    @memset(&cartridge, 0x00);
    cartridge[0x0000] = @intFromEnum(Op.LDA_I);
    cartridge[0x0001] = 0x69;
    cartridge[0x0002] = @intFromEnum(Op.TAX);
    cartridge[0x0003] = @intFromEnum(Op.INX);
    cartridge[0x0004] = @intFromEnum(Op.STA_ZPX);
    cartridge[0x0005] = 0xF0;
    cartridge[0x0006] = @intFromEnum(Op.RET);
    cartridge[0x3FFC] = 0x00;
    cartridge[0x3FFD] = 0x80;
    cpu.insert(cartridge);
    cpu.exec();
    cpu.display();
    try std.testing.expectEqual(0x69, cpu.bus.cpu_mem[0x5A]);
}

pub fn main() void {
    return 0;
}
