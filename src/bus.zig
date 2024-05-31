const std = @import("std");
const builtin = @import("builtin");
const dbg = builtin.mode == std.builtin.OptimizeMode.Debug;

pub const Mirroring = enum { four_screen, horizontal, vertical };

pub const Bus = struct {
    const CPU_MEM_SIZE: usize = 0x10000;
    const CPU_RAM_LO: u16 = 0x0000;
    const CPU_RAM_HI: u16 = 0x1FFF;
    const CPU_RAM_CHUNK: u16 = 0x7FF;
    const PRG_ROM_LO: u16 = 0x8000;
    const PRG_ROM_HI: u16 = 0xFFFF;
    const PRG_ROM_CHUNK: u16 = 0x4000;
    const CHR_ROM_CHUNK: u16 = 0x2000;

    cpu_mem: [CPU_MEM_SIZE]u8,
    prg_rom_mirror: u16,

    pub fn init(ines_path: []const u8) !Bus {
        var file = try std.fs.cwd().openFile(ines_path, .{});
        defer file.close();
        var reader = std.io.bufferedReader(file.reader());
        var in_stream = reader.reader();
        const header = try in_stream.readStruct(packed struct {
            file_header: u32,
            prg_rom_chunks: u8,
            chr_rom_chunks: u8,
            control_1: packed struct {
                mirroring: u1,
                _: u1,
                trainer: u1,
                four_screen_vram: u1,
                mapper_type_lo: u4,
            },
            control_2: packed struct {
                _: u2,
                ines_format: u2,
                mapper_type_hi: u4,
            },
            prg_ram_chunks: u8,
            _: u56,
        });
        const nes_header: u32 = 'N' | 'E' << 8 | 'S' << 16 | 0x1A << 24;
        std.debug.assert(header.file_header == nes_header);
        if (header.control_1.trainer == 1) {
            try in_stream.skipBytes(512, .{});
        }
        const prg_bytes = PRG_ROM_CHUNK * header.prg_rom_chunks;
        var cpu_mem = [_]u8{0} ** CPU_MEM_SIZE;
        _ = in_stream.readAll(cpu_mem[PRG_ROM_LO .. PRG_ROM_LO + prg_bytes]) catch {};
        return Bus{
            .cpu_mem = cpu_mem,
            .prg_rom_mirror = PRG_ROM_LO + prg_bytes,
        };
    }

    pub fn cpu_read_u8(self: Bus, addr: u16) u8 {
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

    pub fn cpu_write_u8(self: *Bus, addr: u16, data: u8) void {
        switch (addr) {
            CPU_RAM_LO...CPU_RAM_HI => self.cpu_mem[addr & CPU_RAM_CHUNK] = data,
            PRG_ROM_LO...PRG_ROM_HI => unreachable,
            else => unreachable,
        }
    }

    pub fn cpu_read_u16(self: Bus, addr: u16) u16 {
        const hi: u16 = @as(u16, self.cpu_read_u8(addr + 1)) << 8;
        const lo: u16 = self.cpu_read_u8(addr);
        return hi | lo;
    }

    pub fn cpu_write_u16(self: *Bus, addr: u16, data: u16) void {
        self.cpu_write_u8(addr, (data & 0xFF));
        self.cpu_write_u8(addr + 1, (data >> 8));
    }
};
