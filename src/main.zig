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
    _ = src;

    var chunk: Chunk = .{};
    defer chunk.deinit(gpa);

    var vm = try Vm.init(gpa, flags);
    defer vm.deinit();

    const constant = try chunk.addConstant(gpa, .{ .float = 1.2 });
    const constant_1 = try chunk.addConstant(gpa, .{ .float = 2 });
    try chunk.appendInstruction(gpa, .{ .load = .{ .dest = @enumFromInt(0), .src = constant } }, 123);
    try chunk.appendInstruction(gpa, .{ .load = .{ .dest = @enumFromInt(5), .src = constant_1 } }, 123);
    try chunk.appendInstruction(gpa, .{ .negate = .{ .dest = @enumFromInt(1), .src = @enumFromInt(0) } }, 126);
    try chunk.appendInstruction(gpa, .{ .div = .{ .dest = @enumFromInt(2), .lhs = @enumFromInt(1), .rhs = @enumFromInt(5) } }, 129);
    try chunk.appendInstruction(gpa, Instruction.ret, 123);

    try vm.interpret(&chunk);

    std.debug.print("{}\n", .{chunk});
    std.debug.print("{any}\n", .{vm.value_stack.items});
}

pub const std_options = .{
    .log_level = .debug,
    .logFn = std.log.defaultLog,
};

const Instruction = @import("instruction.zig").Instruction;

const Chunk = @import("Chunk.zig");
const Vm = @import("Vm.zig");

const std = @import("std");
