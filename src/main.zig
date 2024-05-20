const std = @import("std");

const Cartridge = [0x7FFF]u8;

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
    n: bool,
    v: bool,
    b: bool,
    d: bool,
    i: bool,
    z: bool,
    c: bool,
};

const Cpu = struct {
    reg: Registers,
    mem: [0xFFFF]u8,

    fn read_u8(self: Cpu, pos: u16) u8 {
        // TODO: add logging
        return self.mem[pos];
    }
    fn write_u8(self: *Cpu, pos: u16, data: u8) void {
        // TODO: add logging
        self.mem[pos] = data;
    }

    fn read_u16(self: Cpu, pos: u16) u16 {
        const hi: u16 = @as(u16, self.read_u8(pos + 1)) << 8;
        const lo: u16 = self.read_u8(pos);
        return hi | lo;
    }
    fn write_u16(self: *Cpu, pos: u16, data: u16) void {
        self.write_u8(pos, (data & 0xFF));
        self.write_u8(pos + 1, (data >> 8));
    }

    fn addr_immediate(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 1;
        return pc;
    }
    fn addr_zero_page(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 1;
        return self.read_u8(pc);
    }
    fn addr_zero_page_x(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 1;
        const ret: u8 = self.read_u8(pc) +% self.reg.x;
        return ret;
    }
    fn addr_zero_page_y(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 1;
        const ret: u8 = self.read_u8(pc) +% self.reg.y;
        return ret;
    }
    fn addr_absolute(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 2;
        return self.read_u16(pc);
    }
    fn addr_absolute_x(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 2;
        return self.read_u16(pc) +% self.reg.x;
    }
    fn addr_absolute_y(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 2;
        return self.read_u16(pc) +% self.reg.y;
    }
    fn addr_indirect_x(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 1;
        const ptr: u8 = self.read_u8(pc) +% self.reg.x;
        const hi: u16 = @as(u16, self.read_u8(ptr +% 1)) << 8;
        const lo: u16 = self.read_u8(ptr);
        return hi | lo;
    }
    fn addr_indirect_y(self: *Cpu) u16 {
        const pc: u16 = self.reg.pc;
        self.reg.pc += 1;
        const ptr: u8 = self.read_u8(pc);
        const hi: u16 = @as(u16, self.read_u8(ptr +% 1)) << 8;
        const lo: u16 = self.read_u8(ptr);
        return (hi | lo) +% @as(u16, self.reg.y);
    }

    fn sta(self: *Cpu, addr: u16) void {
        self.write_u8(addr, self.reg.a);
    }
    fn lda(self: *Cpu, addr: u16) void {
        self.reg.a = self.read_u8(addr);
        self.reg.z = self.reg.a == 0;
        self.reg.n = self.reg.a & (1 << 7) != 0;
    }
    fn stx(self: *Cpu, addr: u16) void {
        self.write_u8(addr, self.reg.x);
    }
    fn ldx(self: *Cpu, addr: u16) void {
        self.reg.x = read_u8(addr);
        self.reg.z = self.reg.x == 0;
        self.reg.n = self.reg.x & (1 << 7) != 0;
    }
    fn tax(self: *Cpu) void {
        self.reg.x = self.reg.a;
        self.reg.z = self.reg.x == 0;
        self.reg.n = self.reg.x & (1 << 7) != 0;
    }
    fn inx(self: *Cpu) void {
        self.reg.x += 1;
        self.reg.z = self.reg.x == 0;
        self.reg.n = self.reg.x & (1 << 7) != 0;
    }

    pub fn exec(self: *Cpu) void {
        var opcode: Op = undefined;
        while (true) {
            opcode = @enumFromInt(self.read_u8(self.reg.pc));
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
                // else => {
                //     return;
                // },
            }
        }
    }

    pub fn reset(self: *Cpu) void {
        self.reg.sp = 0;
        self.reg.a = 0;
        self.reg.x = 0;
        self.reg.y = 0;
        self.reg.n = false;
        self.reg.v = false;
        self.reg.b = false;
        self.reg.d = false;
        self.reg.i = false;
        self.reg.z = false;
        self.reg.c = false;
        self.reg.pc = self.read_u16(0xFFFC);
    }

    pub fn insert(self: *Cpu, cartridge: Cartridge) void {
        std.mem.copyForwards(u8, self.mem[0x8000..0xFFFF], &cartridge);
        self.reset();
    }

    pub fn display(self: Cpu) void {
        std.debug.print("\n", .{});
        for (0.., self.mem) |i, m| {
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
    cartridge[0x7FFC] = 0x00;
    cartridge[0x7FFD] = 0x80;
    var cpu: Cpu = undefined;
    @memset(&cpu.mem, 0x00);
    cpu.insert(cartridge);
    cpu.exec();
    cpu.display();
    try std.testing.expectEqual(0x69, cpu.mem[0x5A]);
}

pub fn main() void {
    return 0;
}
