const Context = @This();

const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Elf = @import("Context/Elf.zig");

tag: Tag,
data: []const u8,

pub const Tag = enum {
    elf,
};

pub fn asMut(base: *Context, comptime T: type) ?*T {
    if (base.tag != T.base_tag)
        return null;

    return @fieldParentPtr(T, "base", base);
}

pub fn asConst(base: *const Context, comptime T: type) ?*const T {
    if (base.tag != T.base_tag)
        return null;

    return @fieldParentPtr(T, "base", base);
}

pub fn deinit(base: *Context, gpa: Allocator) void {
    gpa.free(base.data);
}

pub fn destroy(base: *Context, gpa: Allocator) void {
    base.deinit(gpa);
    switch (base.tag) {
        .elf => {
            const parent = @fieldParentPtr(Elf, "base", base);
            parent.deinit(gpa);
            gpa.destroy(parent);
        },
    }
}

pub fn parse(gpa: Allocator, data: []const u8) !*Context {
    if (Elf.isElfFile(data)) {
        return &(try Elf.parse(gpa, data)).base;
    }
    return error.UnknownFileFormat;
}
