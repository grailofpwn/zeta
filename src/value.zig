pub const Value = union(enum) {
    float: f64,
    null: void,

    pub fn isSameTag(a: Value, b: Value) bool {
        return switch (a) {
            .float => b == .float,
            .null => b == .null,
        };
    }

    pub fn format(value: Value, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        switch (value) {
            .float => try writer.print("{d}", .{value.float}),
            .null => try writer.writeAll("<null>"),
        }
    }
};

const std = @import("std");
