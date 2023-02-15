const std = @import("std");

pub fn build(b: *std.Build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    // const zig_dis_x86_64 = b.dependency("zig-dis-x86_64", .{
    //     .target = target,
    //     .optimize = mode,
    // });

    const exe = b.addExecutable(.{
        .name = "zig-objdump",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = mode,
    });
    // exe.addModule("dis_x86_64", zig_dis_x86_64.module("dis_x86_64"));
    exe.addAnonymousModule("dis_x86_64", .{
        .source_file = .{ .path = "zig-dis-x86_64/src/dis_x86_64.zig" },
    });
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
