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
        const shdr = elf.getShdrByName(".text") orelse {
            return writer.writeAll("No .text section found.\n");
        };
        const data = elf.getShdrData(shdr);
        switch (elf.header.e_machine.toTargetCpuArch().?) {
            .x86_64 => try obj.disassembleX8664(data, writer),
            else => |arch| {
                return writer.print("TODO add disassembler for {s}\n", .{@tagName(arch)});
            },
        }
    }
}

fn disassembleX8664(obj: *const ObjDump, data: []const u8, writer: anytype) !void {
    _ = obj;
    var disassembler = Disassembler.init(data);
    while (try disassembler.next()) |inst| {
        try inst.fmtPrint(writer);
        try writer.writeByte('\n');
    }
}
