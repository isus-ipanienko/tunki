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
    STA_IX = 0x81,
    STA_ZP = 0x85,
    STX_ZP = 0x86,
    STA_A = 0x8D,
    STX_A = 0x8E,
    STA_IY = 0x91,
    STA_ZPX = 0x95,
    STX_ZPY = 0x96,
    STA_AX = 0x9D,
    STA_AY = 0x99,
    LDA_IX = 0xA1,
    LDA_ZP = 0xA5,
    LDA_I = 0xA9,
    TAX = 0xAA,
    LDA_A = 0xAD,
    LDA_IY = 0xB1,
    LDA_ZPX = 0xB5,
    LDA_AX = 0xBD,
    LDA_AY = 0xB9,
    INX = 0xE8,
};

const Registers = struct {
    pc: u16,
    sp: u8,
    a: u8,
    x: u8,
    y: u8,

    pub fn init() Registers {
        return Registers{
            .pc = 0,
            .sp = 0,
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
    break_command: bool,
    overflow: bool,
    negative: bool,

    pub fn init() Flags {
        return Flags{
            .carry = false,
            .zero = true,
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

    fn addr_immediate(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 1;
        return pc;
    }

    fn addr_zero_page(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 1;
        return self.bus.cpu_read_u8(pc);
    }

    fn addr_zero_page_x(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 1;
        const ret: u8 = self.bus.cpu_read_u8(pc) +% self.reg.x;
        return ret;
    }

    fn addr_zero_page_y(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 1;
        const ret: u8 = self.bus.cpu_read_u8(pc) +% self.reg.y;
        return ret;
    }

    fn addr_absolute(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 2;
        return self.bus.cpu_read_u16(pc);
    }

    fn addr_absolute_x(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 2;
        return self.bus.cpu_read_u16(pc) +% @as(u16, self.reg.x);
    }

    fn addr_absolute_y(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 2;
        return self.bus.cpu_read_u16(pc) +% @as(u16, self.reg.y);
    }

    fn addr_indirect_x(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 1;
        const ptr: u8 = self.bus.cpu_read_u8(pc) +% self.reg.x;
        const hi: u16 = @as(u16, self.bus.cpu_read_u8(ptr +% 1)) << 8;
        const lo: u16 = @as(u16, self.bus.cpu_read_u8(ptr));
        return hi | lo;
    }

    fn addr_indirect_y(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 1;
        const ptr: u8 = self.bus.cpu_read_u8(pc);
        const hi: u16 = @as(u16, self.bus.cpu_read_u8(ptr +% 1)) << 8;
        const lo: u16 = @as(u16, self.bus.cpu_read_u8(ptr));
        return (hi | lo) +% @as(u16, self.reg.y);
    }

    fn update_flags_from_value(self: *Cpu, val: u8) void {
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
        update_flags_from_value(self, self.reg.a);
    }

    fn ldx(self: *Cpu, addr: u16) void {
        self.reg.x = self.bus.cpu_read_u8(addr);
        update_flags_from_value(self, self.reg.x);
    }

    fn tax(self: *Cpu) void {
        self.reg.x = self.reg.a;
        update_flags_from_value(self, self.reg.x);
    }

    fn inx(self: *Cpu) void {
        self.reg.x += 1;
        update_flags_from_value(self, self.reg.x);
    }

    pub fn exec(self: *Cpu) void {
        var opcode: Op = undefined;
        while (true) {
            opcode = @enumFromInt(self.bus.cpu_read_u8(self.reg.pc));
            self.reg.pc += 1;
            switch (opcode) {
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
                Op.STX_ZP => {
                    self.stx(self.addr_zero_page());
                },
                Op.STX_ZPY => {
                    self.stx(self.addr_zero_page_y());
                },
                Op.STX_A => {
                    self.stx(self.addr_absolute());
                },
                Op.TAX => {
                    self.tax();
                },
                Op.INX => {
                    self.inx();
                },
                Op.RET => {
                    return;
                },
            }
        }
    }

    pub fn reset(self: *Cpu) void {
        self.reg.sp = 0;
        self.reg.a = 0;
        self.reg.x = 0;
        self.reg.y = 0;
        self.flags.carry = false;
        self.flags.zero = true;
        self.flags.interrupt_disable = true;
        self.flags.decimal_mode = false;
        self.flags.break_command = false;
        self.flags.overflow = false;
        self.flags.negative = false;
        self.reg.pc = self.bus.cpu_read_u16(0x00FC);
    }

    pub fn insert(self: *Cpu, cartridge: [0x800]u8) void {
        std.mem.copyForwards(u8, self.bus.cpu_mem[0x0000..0x0800], &cartridge);
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
    var cartridge: [0x800]u8 = undefined;
    @memset(&cartridge, 0x00);
    cartridge[0x0000] = @intFromEnum(Op.LDA_I);
    cartridge[0x0001] = 0x69;
    cartridge[0x0002] = @intFromEnum(Op.TAX);
    cartridge[0x0003] = @intFromEnum(Op.INX);
    cartridge[0x0004] = @intFromEnum(Op.STA_ZPX);
    cartridge[0x0005] = 0xF0;
    cartridge[0x0006] = @intFromEnum(Op.RET);
    cartridge[0x00FC] = 0x00;
    cartridge[0x00FD] = 0x00;
    cpu.insert(cartridge);
    cpu.exec();
    cpu.display();
    try std.testing.expectEqual(0x69, cpu.bus.cpu_mem[0x5A]);
}

pub fn main() void {
    return 0;
}
