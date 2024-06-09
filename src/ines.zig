const std = @import("std");

const Memory = @import("cpu.zig").Memory;

pub const Mirroring = enum { four_screen, horizontal, vertical };

const Header = packed struct {
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
};

pub const FileINES = struct {
    cpu_mem: [Memory.CPU_MEM_SIZE]u8,
    prg_rom_size: u16,

    pub fn init(ines_path: []const u8) !FileINES {
        var file = try std.fs.cwd().openFile(ines_path, .{});
        defer file.close();
        var buffered_reader = std.io.bufferedReader(file.reader());
        var reader = buffered_reader.reader();
        const header = try reader.readStruct(Header);
        const nes_header: u32 = 'N' | 'E' << 8 | 'S' << 16 | 0x1A << 24;
        std.debug.assert(header.file_header == nes_header);
        std.debug.assert(header.control_2.ines_format == 0);
        if (header.control_1.trainer == 1) {
            try reader.skipBytes(512, .{});
        }
        const prg_rom_bytes = Memory.PRG_ROM_CHUNK * header.prg_rom_chunks;
        var cpu_mem = [_]u8{0} ** Memory.CPU_MEM_SIZE;
        _ = reader.readAll(cpu_mem[Memory.PRG_ROM_LO .. Memory.PRG_ROM_LO + prg_rom_bytes]) catch {};
        return FileINES{
            .cpu_mem = cpu_mem,
            .prg_rom_size = prg_rom_bytes,
        };
    }
};
