pub fn Stack(comptime T: type, comptime capacity: u32) type {
    return struct {
        buf: [capacity]T,
        items: []T,

        const Self = @This();

        pub fn init() Self {
            const buf: [capacity]T = undefined;
            return .{
                .buf = buf,
                .items = buf[0..0],
            };
        }

        pub fn push(stack: *Self, val: T) void {
            if (stack.items.len == stack.buf.len)
                @panic("Stack is full cannot push");
            stack.items = stack.buf[0 .. stack.items.len + 1];
            stack.items[stack.items.len - 1] = val;
        }

        pub fn pop(stack: *Self) T {
            if (stack.items.len == 0)
                @panic("Stack is empty cannot pop");
            const val = stack.items[stack.items.len - 1];
            stack.items = stack.buf[0 .. stack.items.len - 1];
            return val;
        }

        pub fn popOrNull(stack: *Self) ?T {
            if (stack.items.len == 0)
                return null;
            const val = stack.items[stack.items.len - 1];
            stack.items = stack.buf[0 .. stack.items.len - 1];
            return val;
        }

        pub fn peek(stack: Self, distance: u32) T {
            return stack.items[stack.items.len - distance - 1];
        }

        pub fn clear(stack: *Self) void {
            stack.items = stack.buf[0..0];
        }

        pub fn format(stack: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;

            try writer.print("stack: ", .{});

            if (stack.items.len == 0) {
                try writer.print("empty", .{});
                return;
            }
            for (stack.items) |item| {
                try writer.print("[ {} ]", .{item});
            }
        }
    };
}

const std = @import("std");
