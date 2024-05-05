value_stack: std.ArrayListUnmanaged(Value) = .{},

chunk: *Chunk,
ip: u32 = 0,

flags: Flags,
gpa: std.mem.Allocator,

pub fn init(gpa: std.mem.Allocator, flags: Flags) !Vm {
    var vm: Vm = .{
        .chunk = undefined,
        .flags = flags,
        .gpa = gpa,
    };

    try vm.value_stack.appendNTimes(gpa, Value.null, 256);

    return vm;
}

pub fn deinit(vm: *Vm) void {
    vm.value_stack.deinit(vm.gpa);
}

pub fn interpret(vm: *Vm, chunk: *Chunk) !void {
    vm.chunk = chunk;

    try vm.run();
}

fn run(vm: *Vm) !void {
    while (true) : (vm.ip += 4) {
        const instruction = try Instruction.decode(vm.chunk.code.items[vm.ip .. vm.ip + 4]);

        if (vm.flags.@"trace-execution") {
            // TODO: stack trace
            std.log.debug("{}", .{instruction.fmt(vm.chunk.*, vm.ip)});
        }

        switch (instruction) {
            .ret => return,
            .add => |args| try vm.binaryOp(.add, args),
            .sub => |args| try vm.binaryOp(.sub, args),
            .mul => |args| try vm.binaryOp(.mul, args),
            .div => |args| try vm.binaryOp(.div, args),
            .negate => |args| {
                const src = vm.value_stack.items[@intFromEnum(args.src)];
                if (src != .float) unreachable; // TODO: runtime error
                vm.value_stack.items[@intFromEnum(args.dest)] = .{ .float = -src.float };
            },
            .load => |args| {
                vm.value_stack.items[@intFromEnum(args.dest)] = vm.chunk.constants.items[args.src];
                std.log.debug("Loaded constant: '{}'", .{vm.value_stack.items[@intFromEnum(args.dest)]});
            },
        }
    }
}

const BinaryOperator = enum { add, sub, mul, div };
pub fn binaryOp(vm: *Vm, op: BinaryOperator, args: Instruction.Binary) !void {
    const dest = &vm.value_stack.items[@intFromEnum(args.dest)];

    const lhs = vm.value_stack.items[@intFromEnum(args.lhs)];
    const rhs = vm.value_stack.items[@intFromEnum(args.rhs)];

    if (!Value.isSameTag(lhs, rhs)) unreachable; // TODO: runtime error

    switch (op) {
        .add => switch (lhs) {
            .float => dest.* = .{ .float = lhs.float + rhs.float },
            .null => unreachable, // TODO: runtime error
        },

        .sub => switch (lhs) {
            .float => dest.* = .{ .float = lhs.float - rhs.float },
            .null => unreachable, // TODO: runtime error
        },
        .mul => switch (lhs) {
            .float => dest.* = .{ .float = lhs.float * rhs.float },
            .null => unreachable, // TODO: runtime error
        },
        .div => switch (lhs) {
            .float => dest.* = .{ .float = lhs.float / rhs.float },
            .null => unreachable, // TODO: runtime error
        },
    }
}

const Value = @import("value.zig").Value;
const Instruction = @import("instruction.zig").Instruction;

const Chunk = @import("Chunk.zig");

const Vm = @This();
const Flags = @import("main.zig").Flags;
const std = @import("std");
