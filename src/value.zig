pub const Value = union(enum) {
    float: f64,
    boolean: bool,
    null: void,

    pub fn isSameTag(a: Value, b: Value) bool {
        return switch (a) {
            .float => b == .float,
            .null => b == .null,
            .boolean => b == .boolean,
        };
    }

    pub fn isFalsey(value: Value) bool {
        return switch (value) {
            .float => false,
            .boolean => !value.boolean,
            .null => true,
        };
    }

    pub fn format(value: Value, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        switch (value) {
            .float => try writer.print("{d}", .{value.float}),
            .boolean => try writer.print("{any}", .{value.boolean}),
            .null => try writer.writeAll("<null>"),
        }
    }
};

const std = @import("std");
