const ObjDump = @This();

const std = @import("std");

const Allocator = std.mem.Allocator;
const Context = @import("Context.zig");
const Disassembler = @import("dis_x86_64").Disassembler;

gpa: Allocator,
ctx: *Context,

pub fn parse(gpa: Allocator, file: std.fs.File) !ObjDump {
    const file_size = try file.getEndPos();
    const data = try file.readToEndAlloc(gpa, file_size);
    errdefer gpa.free(data);

    var obj = ObjDump{
        .gpa = gpa,
        .ctx = undefined,
    };

    obj.ctx = try Context.parse(gpa, data);

    return obj;
}

pub fn deinit(obj: *ObjDump) void {
    obj.ctx.deinit(obj.gpa);
}

pub fn dump(obj: *const ObjDump, writer: anytype) !void {
    if (obj.ctx.asConst(Context.Elf)) |elf| {
        // TODO get all machine code sections, not only .text
        const shdr_index = elf.getShdrIndexByName(".text") orelse {
            return writer.writeAll("No .text section found.\n");
        };
        const shdr = elf.getShdr(shdr_index);
        const data = elf.getShdrData(shdr);

        var symbols = std.ArrayList(std.elf.Elf64_Sym).init(obj.gpa);
        defer symbols.deinit();

        const SymSort = struct {
            pub fn lessThan(ctx: void, lhs: std.elf.Elf64_Sym, rhs: std.elf.Elf64_Sym) bool {
                _ = ctx;
                if (lhs.st_value == rhs.st_value) {
                    const lhs_bind = lhs.st_info >> 4;
                    const rhs_bind = rhs.st_info >> 4;
                    if (lhs_bind == std.elf.STB_GLOBAL) return true;
                    if (lhs_bind == std.elf.STB_WEAK) return switch (rhs_bind) {
                        std.elf.STB_GLOBAL => return false,
                        else => return true,
                    };
                    if (lhs_bind == std.elf.STB_LOCAL and rhs_bind == std.elf.STB_LOCAL) return true;
                    return false;
                }
                return lhs.st_value < rhs.st_value;
            }
        };

        for (elf.symtab.items) |sym| {
            const shndx = sym.st_shndx;
            switch (sym.st_shndx) {
                std.elf.SHN_UNDEF, std.elf.SHN_LIVEPATCH => continue,
                std.elf.SHN_ABS => return error.TODOAbsSymbol,
                std.elf.SHN_COMMON => return error.TODOCommonSymbol,
                else => {},
            }

            if (shdr_index != shndx) continue;
            try symbols.append(sym);
        }

        std.sort.sort(std.elf.Elf64_Sym, symbols.items, {}, SymSort.lessThan);

        var current_offset: ?u64 = null;

        for (symbols.items, 0..) |sym, i| {
            const offset = sym.st_value - shdr.sh_addr;
            if (current_offset) |off| {
                if (off == offset) continue;
            }
            const size = sym.st_size;
            const code = data[offset..][0..size];

            switch (elf.header.e_machine.toTargetCpuArch().?) {
                .x86_64 => try obj.disassembleX8664(code, sym, writer),
                else => |arch| {
                    return writer.print("TODO add disassembler for {s}\n", .{@tagName(arch)});
                },
            }

            if (i + 1 < symbols.items.len) {
                try writer.writeAll("...\n\n");
            }

            current_offset = offset;
        }
    }
}

fn disassembleX8664(obj: *const ObjDump, data: []const u8, sym: std.elf.Elf64_Sym, writer: anytype) !void {
    const elf = obj.ctx.asConst(Context.Elf).?;
    var disassembler = Disassembler.init(data);
    var pos: usize = 0;

    const padding = [_]u8{' '} ** 8;
    const max_inst_length = 8;

    const name = elf.getString(sym.st_name);
    try writer.print("{x:0>16} <{s}>:\n", .{ sym.st_value, name });

    while (try disassembler.next()) |inst| {
        try writer.print("{x:0>16}:", .{sym.st_value + pos});
        try writer.writeAll(&padding);

        const slice = data[pos..disassembler.pos];
        var i: usize = 0;
        while (i < max_inst_length) : (i += 1) {
            if (i < slice.len) {
                try writer.print("{x:0>2} ", .{slice[i]});
            } else {
                try writer.writeAll("   ");
            }
        }

        try inst.fmtPrint(writer);
        try writer.writeByte('\n');

        pos = disassembler.pos;
    }
}
