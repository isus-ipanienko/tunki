const Mirroring = @import("ines.zig").Mirroring;
const FileINES = @import("ines.zig").FileINES;

const RegAddr = struct {
    val1: u8,
    val2: u8,
    first: bool,

    fn init() RegAddr {
        return RegAddr{
            .val1 = 0,
            .val2 = 0,
            .first = true,
        };
    }

    pub fn write(self: *RegAddr, data: u8) void {
        if (self.first) {
            self.val1 = data;
        } else {
            self.val2 = data;
        }
        self.val1 &= 0x3F;
        self.first = !self.first;
    }

    pub fn increment(self: *RegAddr, inc: u8) void {
        const val2: u8 = self.val2;
        self.val2 +%= inc;
        if (val2 > self.val2) {
            self.val1 +%= 1;
        }
        self.val1 &= 0x3F;
    }

    pub fn reset_latch(self: *RegAddr) void {
        self.first = true;
    }

    pub fn get(self: RegAddr) u16 {
        return (@as(u16, self.val1) << 8) | @as(u16, self.val2);
    }
};

const RegControl = packed struct {
    nametable1: u1,
    nametable2: u1,
    vram_add_increment: u1,
    sprite_pattern_addr: u1,
    background_pattern_addr: u1,
    sprite_size: u1,
    master_slave_select: u1,
    generate_nmi: u1,

    fn init() RegControl {
        return RegControl{
            .nametable1 = 0,
            .nametable2 = 0,
            .vram_add_increment = 0,
            .sprite_pattern_addr = 0,
            .background_pattern_addr = 0,
            .sprite_size = 0,
            .master_slave_select = 0,
            .generate_nmi = 0,
        };
    }

    fn get_vram_add_increment(self: RegControl) u8 {
        if (self.vram_add_increment == 1) {
            return 32;
        } else {
            return 1;
        }
    }

    pub fn set(self: *RegControl, val: u8) void {
        self.* = @bitCast(val);
    }
};

const Registers = struct {
    addr: RegAddr,
    control: RegControl,

    fn init() Registers {
        return Registers{
            .addr = RegAddr.init(),
            .control = RegControl.init(),
        };
    }
};

pub const Ppu = struct {
    const PALETTE_TABLE_LO: u16 = 0x3F00;
    const PALETTE_TABLE_HI: u16 = 0x4000;

    reg: Registers,
    chr_rom: [0x2000]u8,
    vram: [0x800]u8,
    mirroring: Mirroring,
    read_buf: u8,
    oam_data: [0x100]u8,
    palette_table: [0x20]u8,

    pub fn vram_addr(self: Ppu, addr: u16) u16 {
        const vram_index: u16 = addr - 0x2000;
        const name_table: u16 = vram_index / 0x400;
        if (self.mirroring == Mirroring.vertical) {
            if (name_table == 2 or name_table == 3) {
                return vram_index - 0x800;
            } else {
                return vram_index;
            }
        } else if (self.mirroring == Mirroring.horizontal) {
            if (name_table == 3) {
                return vram_index - 0x800;
            } else if (name_table == 0) {
                return vram_index;
            } else {
                return vram_index - 0x400;
            }
        } else {
            unreachable;
        }
    }

    pub fn read(self: *Ppu) u8 {
        const addr: u16 = self.reg.addr.get();
        self.reg.addr.increment(self.reg.control.get_vram_add_increment());
        return switch (addr) {
            0x0000...0x1FFF => {
                const data: u8 = self.read_buf;
                self.read_buf = self.chr_rom[addr];
                return data;
            },
            0x2000...0x2FFF => {
                const data: u8 = self.read_buf;
                self.read_buf = self.vram[self.vram_addr(addr)];
                return data;
            },
            0x3000...0x3EFF => unreachable,
            PALETTE_TABLE_LO...PALETTE_TABLE_HI => {
                return self.palette_table[addr - PALETTE_TABLE_LO];
            },
            else => unreachable,
        };
    }

    pub fn init(_: FileINES) Ppu {
        return Ppu{
            .reg = Registers.init(),
            .chr_rom = undefined,
            .palette_table = [_]u8{0} ** 0x20,
            .vram = [_]u8{0} ** 0x800,
            .oam_data = [_]u8{0} ** 0x100,
            .mirroring = undefined,
            .read_buf = 0,
        };
    }
};
