const std = @import("std");

const ObjDump = @import("ObjDump.zig");

var gpa_alloc = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_alloc.allocator();

const usage =
    \\zig-objdump <FILE>
    \\
    \\General options:
    \\-h, --help               Print this help and exit
;

pub fn main() !void {
    var args_arena = std.heap.ArenaAllocator.init(gpa);
    defer args_arena.deinit();
    const arena = args_arena.allocator();

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const all_args = try std.process.argsAlloc(arena);
    const args = all_args[1..];
    if (args.len == 0) {
        try stderr.writeAll("fatal: missing required positional argument FILE\n");
        return;
    }

    const Iterator = struct {
        args: []const []const u8,
        i: usize = 0,
        fn next(it: *@This()) ?[]const u8 {
            if (it.i >= it.args.len) {
                return null;
            }
            defer it.i += 1;
            return it.args[it.i];
        }
    };
    var args_iter = Iterator{ .args = args };

    var positionals = std.ArrayList([]const u8).init(arena);
    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try stdout.writeAll(usage);
            return;
        } else {
            try positionals.append(arg);
        }
    }

    const filename = positionals.items[0];
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var obj = try ObjDump.parse(gpa, file);
    defer obj.deinit();
    try obj.dump(stdout);
}
