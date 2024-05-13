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

pub fn interpret(vm: *Vm, src: [:0]const u8) !void {
    var chunk = Chunk{};
    defer chunk.deinit(vm.gpa);

    const result = try compile(vm, src, &chunk);

    vm.chunk = &chunk;

    try vm.run(result);
}

fn run(vm: *Vm, result: u8) !void {
    while (vm.ip < vm.chunk.code.items.len) : (vm.ip += 4) {
        const instruction = try Instruction.decode(vm.chunk.code.items[vm.ip .. vm.ip + 4]);

        if (vm.flags.@"trace-execution") {
            // TODO: stack trace
            std.log.debug("{}", .{instruction.fmt(vm.chunk.*, vm.ip)});
        }

        switch (instruction) {
            .ret => std.log.info("returning: {any}", .{vm.value_stack.items[result]}),
            .add => |args| try vm.binaryOp(.add, args),
            .sub => |args| try vm.binaryOp(.sub, args),
            .mul => |args| try vm.binaryOp(.mul, args),
            .div => |args| try vm.binaryOp(.div, args),
            .negate => |args| {
                const src = vm.value_stack.items[args.src];
                switch (src) {
                    .float => vm.value_stack.items[args.dest] = .{ .float = -src.float },
                    .boolean => vm.value_stack.items[args.dest] = .{ .boolean = !src.boolean },
                    .null => vm.value_stack.items[args.dest] = .{ .boolean = true },
                }
            },
            .eq => |args| try vm.binaryOp(.eq, args),
            .lt => |args| try vm.binaryOp(.lt, args),
            .le => |args| try vm.binaryOp(.le, args),
            .load => |args| {
                vm.value_stack.items[args.dest] = vm.chunk.constants.items[args.src];
            },
        }
    }
}

const BinaryOperator = enum { add, sub, mul, div, eq, lt, le };
pub fn binaryOp(vm: *Vm, op: BinaryOperator, args: Instruction.Binary) !void {
    const dest = &vm.value_stack.items[args.dest];

    const lhs = vm.value_stack.items[args.lhs];
    const rhs = vm.value_stack.items[args.rhs];

    if (!Value.isSameTag(lhs, rhs)) unreachable; // TODO: runtime error

    switch (op) {
        .eq => switch (lhs) {
            .float => dest.* = .{ .boolean = lhs.float == rhs.float },
            .null => dest.* = .{ .boolean = true },
            .boolean => dest.* = .{ .boolean = lhs.boolean == rhs.boolean },
        },
        .lt => switch (lhs) {
            .float => dest.* = .{ .boolean = lhs.float < rhs.float },
            else => unreachable, // TODO: runtime error
        },
        .le => switch (lhs) {
            .float => dest.* = .{ .boolean = lhs.float <= rhs.float },
            else => unreachable, // TODO: runtime error
        },
        .add => switch (lhs) {
            .float => dest.* = .{ .float = lhs.float + rhs.float },
            else => unreachable, // TODO: runtime error
        },

        .sub => switch (lhs) {
            .float => dest.* = .{ .float = lhs.float - rhs.float },
            else => unreachable, // TODO: runtime error
        },
        .mul => switch (lhs) {
            .float => dest.* = .{ .float = lhs.float * rhs.float },
            else => unreachable, // TODO: runtime error
        },
        .div => switch (lhs) {
            .float => dest.* = .{ .float = lhs.float / rhs.float },
            else => unreachable, // TODO: runtime error
        },
    }
}

pub fn runtimeError(vm: *Vm, comptime message: []const u8, args: anytype) !void {
    std.log.err(message, args);
    std.log.err("[line {d}] in script\n", .{vm.chunk.lines.items[vm.ip]});

    vm.stack.clear();

    return error.RuntimeError;
}

const Value = @import("value.zig").Value;
const Instruction = @import("instruction.zig").Instruction;

const Chunk = @import("Chunk.zig");
const compile = @import("compiler.zig").compile;

const Vm = @This();
const Flags = @import("main.zig").Flags;
const std = @import("std");
