pub const Instruction = union(enum(u8)) {
    load: Assignment,
    eq: Binary,
    lt: Binary,
    le: Binary,
    add: Binary,
    sub: Binary,
    mul: Binary,
    div: Binary,
    negate: Unary,
    print: u8,
    ret: void,

    pub const Binary = struct { dest: u8, lhs: u8, rhs: u8 };
    const Assignment = struct { dest: u8, src: u16 };
    const Unary = struct { dest: u8, src: u8 };

    pub const Opcode = @typeInfo(Instruction).Union.tag_type.?;

    pub fn decode(code: []const u8) !Instruction {
        const opcode = std.meta.intToEnum(Opcode, code[0]) catch return error.InvalidOpcode;

        return switch (opcode) {
            inline else => |tag| @unionInit(
                Instruction,
                @tagName(tag),
                switch (@typeInfo(Instruction).Union.fields[@intFromEnum(tag)].type) {
                    void => {},
                    Assignment => .{
                        .dest = code[1],
                        .src = std.mem.readInt(u16, code[2..4], .little),
                    },
                    Binary => .{
                        .dest = code[1],
                        .lhs = code[2],
                        .rhs = code[3],
                    },
                    Unary => .{
                        .dest = code[1],
                        .src = code[2],
                    },
                    u8 => code[1],
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
                    bytes[1] = args.dest;
                    std.mem.writeInt(u16, bytes[2..4], args.src, .little);
                },
                Binary => {
                    bytes[1] = args.dest;
                    bytes[2] = args.lhs;
                    bytes[3] = args.rhs;
                },
                Unary => {
                    bytes[1] = args.dest;
                    bytes[2] = args.src;
                },
                u8 => bytes[1] = args,
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
                        args.dest,
                        args.src,
                    }),
                    Binary => try writer.print("{d: ^3} {d: ^3} {d: ^3}", .{
                        args.dest,
                        args.lhs,
                        args.rhs,
                    }),
                    Unary => try writer.print("{d: ^3} {d: ^3}", .{
                        args.dest,
                        args.src,
                    }),
                    u8 => try writer.print("{d: ^3}", .{args}),
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
