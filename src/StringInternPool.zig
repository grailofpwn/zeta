strings: std.ArrayListUnmanaged(*String) = .{},
string_map: std.StringHashMapUnmanaged(u32) = .{},
free_list: std.ArrayListUnmanaged(u32) = .{},

pub fn deinit(sip: *StringInternPool, gpa: std.mem.Allocator) void {
    sip.strings.deinit(gpa);
    sip.string_map.deinit(gpa);
    sip.free_list.deinit(gpa);
}

pub fn get(sip: StringInternPool, bytes: []const u8) ?*String {
    const index = try sip.strings.get(bytes) orelse return null;
    return sip.string_map.items[index];
}

pub fn set(sip: *StringInternPool, gpa: std.mem.Allocator, string: *String) !*String {
    const interned = try sip.get(string.bytes);
    if (interned) return interned;

    const free_index = sip.free_list.popOrNull();
    if (free_index) |index| {
        sip.strings[index] = string;
        try sip.string_map.put(gpa, string.bytes, index);
    } else {
        sip.strings.append(string);
        try sip.string_map.put(gpa, string.bytes, sip.strings.items.len - 1);
    }
}

pub fn remove(sip: *StringInternPool, string: *String) bool {
    const index = try sip.string_map.remove(string.bytes) orelse return false;
    sip.free_list.append(index);
    return true;
}

const StringInternPool = @This();
const String = @import("object.zig").String;

const std = @import("std");
