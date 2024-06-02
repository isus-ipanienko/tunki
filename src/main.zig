const std = @import("std");

const Bus = @import("bus.zig").Bus;
const Cpu = @import("cpu.zig").Cpu;
const Op = @import("cpu.zig").Op;

test "cpu" {
    var bus: Bus = try Bus.init("nestest.nes");
    var cpu: Cpu = Cpu.init(&bus);
    cpu.reset();
    std.debug.print("\n", .{});
    var trace: [128]u8 = undefined;
    while (cpu.exec(&trace)) {
        std.debug.print("{s}\n", .{trace});
    }
    std.debug.print("{s}\n", .{trace});
}

pub fn main() !void {
    var bus: Bus = try Bus.init("nestest.nes");
    var cpu: Cpu = Cpu.init(&bus);
    cpu.reset();
    const trace: void = undefined;
    while (cpu.exec(trace)) {}
}
