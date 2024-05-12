const std = @import("std");

const Cartridge = u8[0x8000];

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
    mem: u8[0xFFFF],

    fn read_u8(pos: u16) u8 {
        // TODO: add logging
        return .mem[pos];
    }
    fn write_u8(pos: u16, data: u8) void {
        // TODO: add logging
        .mem[pos] = data;
    }

    fn read_u16(pos: u16) u16 {
        const hi: u16 = @as(u16, read_u8(pos + 1)) << 8;
        const lo: u16 = read_u8(pos);
        return hi | lo;
    }
    fn write_u16(pos: u16, data: u16) void {
        write_u8(pos, (data & 0xFF));
        write_u8(pos + 1, (data >> 8));
    }

    fn addr_immediate() u16 {
        const pc: u16 = .reg.pc;
        .reg.pc += 1;
        return pc;
    }
    fn addr_zero_page() u16 {
        const pc: u16 = .reg.pc;
        .reg.pc += 1;
        return read_u8(pc);
    }
    fn addr_zero_page_x() u16 {
        const pc: u16 = .reg.pc;
        .reg.pc += 1;
        const ret: u8 = read_u8(pc) + .reg.x;
        return ret;
    }
    fn addr_zero_page_y() u16 {
        const pc: u16 = .reg.pc;
        .reg.pc += 1;
        const ret: u8 = read_u8(pc) + .reg.y;
        return ret;
    }
    fn addr_absolute() u16 {
        const pc: u16 = .reg.pc;
        .reg.pc += 2;
        return read_u16(pc);
    }
    fn addr_absolute_x() u16 {
        const pc: u16 = .reg.pc;
        .reg.pc += 2;
        return read_u16(pc) + .reg.x;
    }
    fn addr_absolute_y() u16 {
        const pc: u16 = .reg.pc;
        .reg.pc += 2;
        return read_u16(pc) + .reg.y;
    }
    fn addr_indirect_x() u16 {
        const ptr: u8 = read_u8(.reg.pc) + .reg.x;
        const hi: u16 = @as(u16, read_u8(ptr + 1)) << 8;
        const lo: u16 = read_u8(ptr);
        return hi | lo;
    }
    fn addr_indirect_y() u16 {
        const ptr: u8 = read_u8(.reg.pc);
        const hi: u16 = @as(u16, read_u8(ptr + 1)) << 8;
        const lo: u16 = read_u8(ptr);
        return (hi | lo) + @as(u16, .reg.y);
    }

    fn sta(addr: u16) void {
        write_u8(addr, .reg.a);
    }
    fn lda(addr: u16) void {
        .reg.a = read_u8(addr);
        .reg.z = .reg.a == 0;
        .reg.n = .reg.a & (1 << 7);
    }
    fn stx(addr: u16) void {
        write_u8(addr, .reg.x);
    }
    fn ldx(addr: u16) void {
        .reg.x = read_u8(addr);
        .reg.z = .reg.x == 0;
        .reg.n = .reg.x & (1 << 7);
    }
    fn tax() void {
        .reg.x = .reg.a;
        .reg.z = .reg.x == 0;
        .reg.n = .reg.x & (1 << 7);
    }
    fn inx() void {
        .reg.x += 1;
        .reg.z = .reg.x == 0;
        .reg.n = .reg.x & (1 << 7);
    }

    pub fn exec() void {
        var opcode: Op = undefined;
        while (true) {
            opcode = read_u8(.reg.pc);
            .reg.pc += 1;
            switch (opcode) {
                Op.STA_ZP => {
                    sta(addr_zero_page());
                },
                Op.STA_ZPX => {
                    sta(addr_zero_page_x());
                },
                Op.STA_A => {
                    sta(addr_absolute());
                },
                Op.STA_AX => {
                    sta(addr_absolute_x());
                },
                Op.STA_AY => {
                    sta(addr_absolute_y());
                },
                Op.STA_IX => {
                    sta(addr_indirect_x());
                },
                Op.STA_IY => {
                    sta(addr_indirect_y());
                },
                Op.LDA_I => {
                    lda(addr_immediate());
                },
                Op.LDA_ZP => {
                    lda(addr_zero_page());
                },
                Op.LDA_ZPX => {
                    lda(addr_zero_page_x());
                },
                Op.LDA_A => {
                    lda(addr_absolute());
                },
                Op.LDA_AX => {
                    lda(addr_absolute_x());
                },
                Op.LDA_AY => {
                    lda(addr_absolute_y());
                },
                Op.LDA_IX => {
                    lda(addr_indirect_x());
                },
                Op.LDA_IY => {
                    lda(addr_indirect_y());
                },
                Op.STX_ZP => {
                    stx(addr_zero_page());
                },
                Op.STX_ZPY => {
                    stx(addr_zero_page_y());
                },
                Op.STX_A => {
                    stx(addr_absolute());
                },
                Op.TAX => {
                    tax();
                },
                Op.INX => {
                    inx();
                },
                Op.RET => {
                    return;
                },
                else => {
                    return;
                },
            }
        }
    }

    pub fn reset() void {
        .reg.sp = 0;
        .reg.a = 0;
        .reg.x = 0;
        .reg.y = 0;
        .reg.n = false;
        .reg.v = false;
        .reg.b = false;
        .reg.d = false;
        .reg.i = false;
        .reg.z = false;
        .reg.c = false;
        .reg.pc = read_u16(0xFFFC);
    }

    pub fn insert(cartridge: Cartridge) void {
        std.mem.copy(&.mem[0x8000], &cartridge[0], cartridge.size());
        reset();
    }
};

test "test cpu" {
    var cartridge: Cartridge = Cartridge;
    cartridge[0x0001] = Op.LDA_I;
    cartridge[0x0002] = 0x69;
    cartridge[0x0003] = Op.TAX;
    cartridge[0x0004] = Op.INX;
    cartridge[0x0005] = Op.STA_ZPX;
    cartridge[0x0006] = 0xF0;
    cartridge[0x0007] = Op.RET;
    cartridge[0x7FFC] = 0x00;
    cartridge[0x7FFD] = 0x80;
    var cpu: Cpu = Cpu;
    cpu.insert(cartridge);
    cpu.exec();
    for (0.., cpu.mem) |i, m| {
        if (m) {
            std.io.stderr.printf("0x%zx: 0x%x\n", i, m);
        }
    }
    return cpu.mem[0x5A] == 0x69;
}

pub fn main() void {
    return 0;
}
