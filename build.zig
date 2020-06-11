const Builder = @import("std").build.Builder;
const SubSystem = @import("builtin").Target.SubSystem;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const cross_target = b.standardTargetOptions(.{});

    const exe = b.addExecutable("disk-info", "src/main.zig");
    exe.addPackagePath("win32", "./dependencies/zig-win32/src/main.zig");
    exe.linkSystemLibrary("c");
    exe.setBuildMode(mode);
    exe.install();
    exe.setTarget(cross_target);
    exe.subsystem = SubSystem.Windows;

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const bitblit_exe = b.addExecutable("disk-info-bitblit", "src/bitblit_main.zig");
    bitblit_exe.addPackagePath("win32", "./dependencies/zig-win32/src/main.zig");
    bitblit_exe.linkSystemLibrary("c");
    bitblit_exe.setBuildMode(mode);
    bitblit_exe.install();
    const bitblit_run_cmd = bitblit_exe.run();
    bitblit_run_cmd.step.dependOn(b.getInstallStep());

    var tests = b.addTest("src/disk.zig");
    tests.addPackagePath("win32", "./dependencies/zig-win32/src/main.zig");
    tests.linkSystemLibrary("c");
    tests.setBuildMode(mode);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const bitblit_run_step = b.step("run-bitblit", "Run the app with win32 bitblitting");
    bitblit_run_step.dependOn(&bitblit_run_cmd.step);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&tests.step);
}
