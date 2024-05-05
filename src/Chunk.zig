code: std.ArrayListUnmanaged(u8) = .{},
lines: std.MultiArrayList(LineRle) = .{},

constants: std.ArrayListUnmanaged(Value) = .{},

const LineRle = struct {
    count: u32,
    line: u32,
};

pub fn deinit(chunk: *Chunk, gpa: std.mem.Allocator) void {
    chunk.code.deinit(gpa);
    chunk.lines.deinit(gpa);
    chunk.constants.deinit(gpa);
}

pub fn addConstant(chunk: *Chunk, gpa: std.mem.Allocator, value: Value) !u16 {
    try chunk.constants.append(gpa, value);
    if (chunk.constants.items.len > std.math.maxInt(u16)) {
        return error.MaxConstantsExceeded;
    }

    return @intCast(chunk.constants.items.len - 1);
}

pub fn appendInstruction(chunk: *Chunk, gpa: std.mem.Allocator, instruction: Instruction, line: u32) !void {
    try chunk.code.appendSlice(gpa, &instruction.encode());

    var line_rle_last: LineRle = chunk.lines.popOrNull() orelse .{ .count = 0, .line = line };
    if (line_rle_last.line == line) {
        line_rle_last.count += 1;
        try chunk.lines.append(gpa, line_rle_last);
    } else {
        try chunk.lines.append(gpa, line_rle_last);
        try chunk.lines.append(gpa, .{ .count = 1, .line = line });
    }
}

pub fn getLine(chunk: Chunk, ip: u32) u32 {
    var ip_accum: u32 = 0;

    for (chunk.lines.items(.count), 0..) |count, idx| {
        if (ip_accum + count > ip) {
            return chunk.lines.get(idx).line;
        }

        ip_accum += count;
    }

    return chunk.lines.get(0).line;
}

pub fn format(
    chunk: Chunk,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;

    var ip: u32 = 0;
    while (ip < chunk.code.items.len) : (ip += 4) {
        if (Instruction.decode(chunk.code.items[ip .. ip + 4])) |instruction| {
            try writer.print("{}\n", .{instruction.fmt(chunk, ip / 4)});
        } else |_| {
            try writer.print("invalid opcode: {any}\n", .{chunk.code.items[ip .. ip + 4]});
        }
    }
}

const Value = @import("value.zig").Value;

const Instruction = @import("instruction.zig").Instruction;
const Chunk = @This();
const std = @import("std");
