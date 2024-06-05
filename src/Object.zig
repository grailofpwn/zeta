tag: Tag,
next: *Object,

const Tag = enum { string };

fn TypeOf(tag: Tag) type {
    switch (tag) {
        .string => *String,
    }
}

pub fn asString(object: *Object) *String {
    return @alignCast(@fieldParentPtr("object", object));
}

fn create(vm: Vm, comptime tag: Tag) !*Object {
    const ptr = vm.gpa.create(TypeOf(tag));
    ptr.object = .{ .tag = tag, .next = vm.objects };
    vm.objects = &ptr.object;

    return &ptr.object;
}

fn destroy(object: *Object, vm: Vm) void {
    switch (TypeOf(object.tag)) {
        inline else => |ObjectParent| {
            const ptr: ObjectParent = @alignCast(@fieldParentPtr("object", object));
            ptr.destroy(vm);
        },
    }
}

const String = struct {
    object: Object,
    bytes: []const u8,

    pub fn copy(vm: Vm, bytes: []const u8) !*String {
        if (vm.strings.get(bytes)) |string| return string;

        const bytes_alloc = try vm.gpa.alloc(u8, bytes.len);
        @memcpy(bytes_alloc, bytes);
        return try String.create(vm, bytes_alloc);
    }

    pub fn take(vm: Vm, bytes: []const u8) !*String {
        if (vm.strings.get(bytes)) |string| {
            vm.gpa.free(bytes);
            return string;
        }
        return try String.create(vm, bytes);
    }

    fn create(vm: Vm, bytes: []const u8) !*String {
        const string: *String = (try Object.create(vm, .string)).asString();
        errdefer string.destroy(vm);

        string.*.bytes = bytes;

        try vm.strings.set(vm.gpa, string);
        return string;
    }

    pub fn destroy(string: *String, vm: Vm) void {
        vm.gpa.free(string.bytes);
        vm.gpa.destroy(&string.object);
    }

    pub fn concat(vm: Vm, a: *Object, b: *Object) !*String {
        const a_str = a.asString();
        const b_str = b.asString();

        const bytes = try vm.gpa.alloc(u8, a_str.bytes.len + b_str.bytes.len);
        @memcpy(bytes, a_str.bytes);
        @memcpy(bytes + a_str.bytes.len, b_str.bytes);

        return try String.create(vm, bytes);
    }

    pub fn format(string: *String, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s}", .{string.bytes});
    }
};

pub fn format(object: *Object, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;

    switch (object.tag) {
        .string => try writer.print("{}", .{object.asString()}),
    }
}

const Object = @This();

const Vm = @import("Vm.zig");

const std = @import("std");
