const Elf = @This();

const std = @import("std");
const assert = std.debug.assert;

const Allocator = std.mem.Allocator;
const Context = @import("../Context.zig");

pub const base_tag: Context.Tag = .elf;

base: Context,
header: std.elf.Elf64_Ehdr,
symtab_shndx: ?u16 = null,
symtab: std.ArrayListUnmanaged(std.elf.Elf64_Sym) = .{},

pub fn isElfFile(data: []const u8) bool {
    // TODO: 32bit ELF files
    const header = @ptrCast(*const std.elf.Elf64_Ehdr, @alignCast(@alignOf(std.elf.Elf64_Ehdr), data.ptr)).*;
    return std.mem.eql(u8, "\x7fELF", header.e_ident[0..4]);
}

pub fn deinit(elf: *Elf, gpa: Allocator) void {
    elf.symtab.deinit(gpa);
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

    const shdrs = elf.getShdrs();
    const symtab_shndx = for (shdrs, 0..) |shdr, i| switch (shdr.sh_type) {
        std.elf.SHT_SYMTAB => break @intCast(u16, i),
        else => {},
    } else null;

    if (symtab_shndx) |shndx| {
        const symtab_shdr = elf.getShdr(shndx);
        const symtab_data = elf.getShdrData(symtab_shdr);
        const nsyms = @divExact(symtab_data.len, @sizeOf(std.elf.Elf64_Sym));
        try elf.symtab.appendSlice(
            gpa,
            @ptrCast([*]const std.elf.Elf64_Sym, @alignCast(@alignOf(std.elf.Elf64_Sym), symtab_data))[0..nsyms],
        );
    }
    elf.symtab_shndx = symtab_shndx;

    return elf;
}

pub fn getShdrIndexByName(elf: *const Elf, name: []const u8) ?u32 {
    const shdrs = elf.getShdrs();
    for (shdrs, 0..) |shdr, i| {
        const shdr_name = elf.getShString(shdr.sh_name);
        if (std.mem.eql(u8, shdr_name, name)) return @intCast(u32, i);
    }
    return null;
}

pub fn getShdrByName(elf: *const Elf, name: []const u8) ?std.elf.Elf64_Shdr {
    const index = elf.getShdrIndexByName(name) orelse return null;
    return elf.getShdr(index);
}

pub fn getShdrs(elf: *const Elf) []const std.elf.Elf64_Shdr {
    const shdrs = @ptrCast(
        [*]const std.elf.Elf64_Shdr,
        @alignCast(@alignOf(std.elf.Elf64_Shdr), elf.base.data.ptr + elf.header.e_shoff),
    )[0..elf.header.e_shnum];
    return shdrs;
}

pub fn getShdr(elf: *const Elf, shndx: u32) std.elf.Elf64_Shdr {
    return elf.getShdrs()[shndx];
}

pub fn getShdrData(elf: *const Elf, shdr: std.elf.Elf64_Shdr) []const u8 {
    return elf.base.data[shdr.sh_offset..][0..shdr.sh_size];
}

pub fn getShString(elf: *const Elf, off: u32) []const u8 {
    const shdr = elf.getShdrs()[elf.header.e_shstrndx];
    const shstrtab = elf.getShdrData(shdr);
    assert(off < shstrtab.len);
    return std.mem.sliceTo(@ptrCast([*:0]const u8, shstrtab.ptr + off), 0);
}

pub fn getStrtab(elf: *const Elf) []const u8 {
    const symtab_shndx = elf.symtab_shndx orelse return &[0]u8{};
    const symtab_shdr = elf.getShdr(symtab_shndx);
    const strtab_shdr = elf.getShdr(symtab_shdr.sh_link);
    return elf.getShdrData(strtab_shdr);
}

pub fn getString(elf: *const Elf, off: u32) []const u8 {
    const strtab = elf.getStrtab();
    assert(off < strtab.len);
    return std.mem.sliceTo(@ptrCast([*:0]const u8, strtab.ptr + off), 0);
}
