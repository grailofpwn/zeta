pub const Flags = struct {
    @"trace-execution": bool = false,
    @"dump-ir": bool = false,
};

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();

    const gpa = gpa_state.allocator();

    const Flag = std.meta.FieldEnum(Flags);

    var flags: Flags = .{};
    var positional: std.ArrayListUnmanaged([]const u8) = .{};
    defer positional.deinit(gpa);

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();

    _ = args.skip(); // command name
    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--")) {
            switch (std.meta.stringToEnum(Flag, arg[2..]).?) {
                inline else => |tag| @field(flags, @tagName(tag)) = true,
            }
        } else {
            try positional.append(gpa, arg);
        }
    }

    if (positional.items.len == 1) {
        var file = try std.fs.cwd().openFile(positional.items[0], .{});
        defer file.close();

        const src: [:0]u8 = try file.readToEndAllocOptions(
            gpa,
            std.math.maxInt(u32),
            null,
            @alignOf(u8),
            0,
        );
        defer gpa.free(src);

        try run(gpa, src, flags);
    } else {
        const stdout = std.io.getStdOut().writer();
        try stdout.print("Usage: zeta <file>\n", .{});
    }
}

fn run(gpa: std.mem.Allocator, src: [:0]const u8, flags: Flags) !void {
    var vm = try Vm.init(gpa, flags);
    defer vm.deinit();

    try vm.interpret(src);
}

pub const std_options = .{
    .log_level = .debug,
    .logFn = std.log.defaultLog,
};

const Instruction = @import("instruction.zig").Instruction;

const Chunk = @import("Chunk.zig");
const Vm = @import("Vm.zig");

const std = @import("std");
