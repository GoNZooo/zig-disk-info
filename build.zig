const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("disk-info", "src/main.zig");
    exe.addPackagePath("win32", "./dependencies/zig-win32/src/main.zig");
    // exe.addIncludeDir("C:/Program Files (x86)/Windows Kits/10/Include/10.0.18362.0/um");
    // exe.addIncludeDir("C:/Program Files (x86)/Windows Kits/10/Include/10.0.18362.0/ucrt");
    // exe.addIncludeDir("C:/Program Files (x86)/Windows Kits/10/Include/10.0.18362.0/winrt");
    // exe.addIncludeDir("C:/Program Files (x86)/Windows Kits/10/Include/10.0.18362.0/shared");
    // exe.addIncludeDir("C:/Program Files (x86)/Microsoft Visual Studio 14.0/VC/include");
    exe.linkSystemLibrary("c");
    // exe.linkSystemLibrary("gdi32");
    // exe.linkSystemLibrary("user32");
    // exe.linkSystemLibrary("kernel32");
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
