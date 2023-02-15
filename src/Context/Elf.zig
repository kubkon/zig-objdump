const Elf = @This();

const std = @import("std");

const Allocator = std.mem.Allocator;
const Context = @import("../Context.zig");

pub const base_tag: Context.Tag = .elf;

base: Context,
header: std.elf.Elf64_Ehdr,

pub fn isElfFile(data: []const u8) bool {
    // TODO: 32bit ELF files
    const header = @ptrCast(*const std.elf.Elf64_Ehdr, @alignCast(@alignOf(std.elf.Elf64_Ehdr), data.ptr)).*;
    return std.mem.eql(u8, "\x7fELF", header.e_ident[0..4]);
}

pub fn deinit(elf: *Elf, gpa: Allocator) void {
    _ = elf;
    _ = gpa;
}

pub fn parse(gpa: Allocator, data: []const u8) !*Elf {
    const elf = try gpa.create(Elf);
    errdefer gpa.destroy(elf);

    elf.* = .{
        .base = .{
            .tag = .elf,
            .data = data,
        },
        .header = undefined,
    };
    elf.header = @ptrCast(*const std.elf.Elf64_Ehdr, @alignCast(@alignOf(std.elf.Elf64_Ehdr), data.ptr)).*;

    return elf;
}

pub fn getMachineCode(elf: *const Elf) ?[]const u8 {
    // TODO get all machine code sections, not only .text
    const shdr = elf.getShdrByName(".text") orelse return null;
    return elf.getShdrData(shdr);
}

pub fn getShdrByName(elf: *const Elf, name: []const u8) ?std.elf.Elf64_Shdr {
    const shdrs = elf.getShdrs();
    for (shdrs) |shdr| {
        const shdr_name = elf.getShString(shdr.sh_name);
        if (std.mem.eql(u8, shdr_name, name)) return shdr;
    }
    return null;
}

pub fn getShdrs(elf: *const Elf) []const std.elf.Elf64_Shdr {
    const shdrs = @ptrCast(
        [*]const std.elf.Elf64_Shdr,
        @alignCast(@alignOf(std.elf.Elf64_Shdr), elf.base.data.ptr + elf.header.e_shoff),
    )[0..elf.header.e_shnum];
    return shdrs;
}

pub fn getShdrData(elf: *const Elf, shdr: std.elf.Elf64_Shdr) []const u8 {
    return elf.base.data[shdr.sh_offset..][0..shdr.sh_size];
}

pub fn getShString(elf: *const Elf, off: u32) []const u8 {
    const shdr = elf.getShdrs()[elf.header.e_shstrndx];
    const shstrtab = elf.getShdrData(shdr);
    std.debug.assert(off < shstrtab.len);
    return std.mem.sliceTo(@ptrCast([*:0]const u8, shstrtab.ptr + off), 0);
}
