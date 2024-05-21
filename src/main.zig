const std = @import("std");

const Cartridge = [0x800]u8;

const Bus = struct {
    cpu_ram: [0x800]u8,

    pub fn init() Bus {
        return Bus{
            .cpu_ram = [_]u8{0} ** 0x800,
        };
    }

    fn read_u8(self: Bus, pos: u16) u8 {
        // TODO: add logging
        return switch (pos) {
            0x0000...0x1FFF => {
                return self.cpu_ram[pos & 0x07FF];
            },
            0x2000...0x3FFF => {
                return 0;
            },
            else => 0,
        };
    }

    fn write_u8(self: *Bus, pos: u16, data: u8) void {
        // TODO: add logging
        switch (pos) {
            0x0000...0x1FFF => {
                self.cpu_ram[pos & 0x07FF] = data;
            },
            0x2000...0x3FFF => {},
            else => {},
        }
    }

    fn read_u16(self: Bus, pos: u16) u16 {
        const hi: u16 = @as(u16, self.read_u8(pos + 1)) << 8;
        const lo: u16 = self.read_u8(pos);
        return hi | lo;
    }

    fn write_u16(self: *Bus, pos: u16, data: u16) void {
        self.write_u8(pos, (data & 0xFF));
        self.write_u8(pos + 1, (data >> 8));
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
        return self.bus.read_u8(pc);
    }

    fn addr_zero_page_x(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 1;
        const ret: u8 = self.bus.read_u8(pc) +% self.reg.x;
        return ret;
    }

    fn addr_zero_page_y(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 1;
        const ret: u8 = self.bus.read_u8(pc) +% self.reg.y;
        return ret;
    }

    fn addr_absolute(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 2;
        return self.bus.read_u16(pc);
    }

    fn addr_absolute_x(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 2;
        return self.bus.read_u16(pc) +% self.reg.x;
    }

    fn addr_absolute_y(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 2;
        return self.bus.read_u16(pc) +% self.reg.y;
    }

    fn addr_indirect_x(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 1;
        const ptr: u8 = self.bus.read_u8(pc) +% self.reg.x;
        const hi: u16 = @as(u16, self.bus.read_u8(ptr +% 1)) << 8;
        const lo: u16 = self.bus.read_u8(ptr);
        return hi | lo;
    }

    fn addr_indirect_y(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 1;
        const ptr: u8 = self.bus.read_u8(pc);
        const hi: u16 = @as(u16, self.bus.read_u8(ptr +% 1)) << 8;
        const lo: u16 = self.bus.read_u8(ptr);
        return (hi | lo) +% @as(u16, self.reg.y);
    }

    fn sta(self: *Cpu, addr: u16) void {
        self.bus.write_u8(addr, self.reg.a);
    }

    fn lda(self: *Cpu, addr: u16) void {
        self.reg.a = self.bus.read_u8(addr);
        self.flags.zero = self.reg.a == 0;
        self.flags.negative = self.reg.a & (1 << 7) != 0;
    }

    fn stx(self: *Cpu, addr: u16) void {
        self.bus.write_u8(addr, self.reg.x);
    }

    fn ldx(self: *Cpu, addr: u16) void {
        self.reg.x = self.bus.read_u8(addr);
        self.flags.zero = self.reg.x == 0;
        self.flags.negative = self.reg.x & (1 << 7) != 0;
    }

    fn tax(self: *Cpu) void {
        self.reg.x = self.reg.a;
        self.flags.zero = self.reg.x == 0;
        self.flags.negative = self.reg.x & (1 << 7) != 0;
    }

    fn inx(self: *Cpu) void {
        self.reg.x += 1;
        self.flags.zero = self.reg.x == 0;
        self.flags.negative = self.reg.x & (1 << 7) != 0;
    }

    pub fn exec(self: *Cpu) void {
        var opcode: Op = undefined;
        while (true) {
            opcode = @enumFromInt(self.bus.read_u8(self.reg.pc));
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
        self.reg.pc = self.bus.read_u16(0x00FC);
    }

    pub fn insert(self: *Cpu, cartridge: Cartridge) void {
        std.mem.copyForwards(u8, self.bus.cpu_ram[0x0000..0x0800], &cartridge);
        self.reset();
    }

    pub fn display(self: Cpu) void {
        std.debug.print("\n", .{});
        for (0.., self.bus.cpu_ram) |i, m| {
            if (m > 0) {
                std.debug.print("0x{X}: 0x{X}\n", .{ i, m });
            }
        }
    }
};

test "cpu" {
    var cartridge: Cartridge = undefined;
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
    var bus: Bus = Bus.init();
    var cpu: Cpu = Cpu.init(&bus);
    @memset(&cpu.bus.cpu_ram, 0x00);
    cpu.insert(cartridge);
    cpu.exec();
    cpu.display();
    try std.testing.expectEqual(0x69, cpu.bus.cpu_ram[0x5A]);
}

pub fn main() void {
    return 0;
}
