const std = @import("std");

const FileINES = @import("ines.zig").FileINES;
const Cpu = @import("cpu.zig").Cpu;
const Ppu = @import("ppu.zig").Ppu;

test "cpu" {
    const ines: FileINES = try FileINES.init("nestest.nes");
    var ppu: Ppu = undefined;
    var cpu: Cpu = Cpu.init(ines, &ppu);
    ppu = Ppu.init(ines);
    std.debug.print("\n", .{});
    var trace: [128]u8 = undefined;
    while (cpu.exec(&trace)) {
        std.debug.print("{s}\n", .{trace});
    }
    std.debug.print("{s}\n", .{trace});
}

pub fn main() !void {
    const ines: FileINES = try FileINES.init("nestest.nes");
    var cpu: Cpu = Cpu.init(ines);
    const trace: void = undefined;
    while (cpu.exec(trace)) {}
}
