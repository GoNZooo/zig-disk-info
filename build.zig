const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("disk-info", "src/main.zig");
    exe.addPackagePath("win32", "./dependencies/zig-win32/src/main.zig");
    exe.linkSystemLibrary("c");
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    var tests = b.addTest("src/disk.zig");
    tests.addPackagePath("win32", "./dependencies/zig-win32/src/main.zig");
    tests.linkSystemLibrary("c");
    tests.setBuildMode(mode);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&tests.step);
}
