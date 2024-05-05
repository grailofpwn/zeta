pub const Register = enum(u8) { _ };

pub const Instruction = union(enum(u8)) {
    load: Assignment,
    add: Binary,
    sub: Binary,
    mul: Binary,
    div: Binary,
    negate: Unary,
    ret: void,

    pub const Binary = struct { dest: Register, lhs: Register, rhs: Register };
    const Assignment = struct { dest: Register, src: u16 };
    const Unary = struct { dest: Register, src: Register };

    const Opcode = @typeInfo(Instruction).Union.tag_type.?;

    pub fn decode(code: []const u8) !Instruction {
        const opcode = std.meta.intToEnum(Opcode, code[0]) catch return error.InvalidOpcode;

        return switch (opcode) {
            inline else => |tag| @unionInit(
                Instruction,
                @tagName(tag),
                switch (@typeInfo(Instruction).Union.fields[@intFromEnum(tag)].type) {
                    void => {},
                    Assignment => .{
                        .dest = @enumFromInt(code[1]),
                        .src = std.mem.readInt(u16, code[2..4], .little),
                    },
                    Binary => .{
                        .dest = @enumFromInt(code[1]),
                        .lhs = @enumFromInt(code[2]),
                        .rhs = @enumFromInt(code[3]),
                    },
                    Unary => .{
                        .dest = @enumFromInt(code[1]),
                        .src = @enumFromInt(code[2]),
                    },
                    else => unreachable,
                },
            ),
        };
    }

    pub fn encode(instruction: Instruction) [4]u8 {
        var bytes: [4]u8 = undefined;
        bytes[0] = @intFromEnum(instruction);

        switch (instruction) {
            inline else => |args| switch (@TypeOf(args)) {
                void => @memset(bytes[1..4], 0),
                Assignment => {
                    bytes[1] = @intFromEnum(args.dest);
                    std.mem.writeInt(u16, bytes[2..4], args.src, .little);
                },
                Binary => {
                    bytes[1] = @intFromEnum(args.dest);
                    bytes[2] = @intFromEnum(args.lhs);
                    bytes[3] = @intFromEnum(args.rhs);
                },
                Unary => {
                    bytes[1] = @intFromEnum(args.dest);
                    bytes[2] = @intFromEnum(args.src);
                },
                else => unreachable,
            },
        }
        return bytes;
    }

    pub fn fmt(instruction: Instruction, chunk: Chunk, ip: u32) InstructionFmt {
        return InstructionFmt{
            .instruction = instruction,
            .chunk = chunk,
            .ip = ip,
        };
    }

    pub const InstructionFmt = struct {
        instruction: Instruction,
        chunk: Chunk,
        ip: u32,

        pub fn format(
            instruction_fmt: InstructionFmt,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print("{x:0>4} ", .{instruction_fmt.ip});

            const line_current: u32 = instruction_fmt.chunk.getLine(instruction_fmt.ip);

            if (instruction_fmt.ip != 0) {
                const line_previous: u32 = instruction_fmt.chunk.getLine(instruction_fmt.ip - 1);
                if (line_current == line_previous) {
                    try writer.writeAll("   | ");
                } else {
                    try writer.print("{d: >4} ", .{line_current});
                }
            } else {
                try writer.print("{d: >4} ", .{line_current});
            }

            try writer.print("{s: <8}", .{@tagName(instruction_fmt.instruction)});
            switch (instruction_fmt.instruction) {
                inline else => |args| switch (@TypeOf(args)) {
                    void => {},
                    Assignment => try writer.print("{d: ^3} {d: ^3}", .{
                        @intFromEnum(args.dest),
                        args.src,
                    }),
                    Binary => try writer.print("{d: ^3} {d: ^3} {d: ^3}", .{
                        @intFromEnum(args.dest),
                        @intFromEnum(args.lhs),
                        @intFromEnum(args.rhs),
                    }),
                    Unary => try writer.print("{d: ^3} {d: ^3}", .{
                        @intFromEnum(args.dest),
                        @intFromEnum(args.src),
                    }),
                    else => unreachable,
                },
            }
        }
    };
};

const Value = @import("value.zig").Value;

const Chunk = @import("Chunk.zig");
const Vm = @import("Vm.zig");

const std = @import("std");
