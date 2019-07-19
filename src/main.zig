const std = @import("std");
const disk = @import("disk.zig");
const memory = std.mem;
const heap = std.heap;
const warn = std.debug.warn;
const win32 = @import("bindings/win32.zig");

pub fn winMain() anyerror!void {
    const class_name = "className";
    const window_name = "windowName";
    warn("wut\n");
    const result = win32.CreateWindowEx(
        0,
        &class_name,
        &window_name,
        0,
        0,
        200,
        200,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
    );
    warn("{}\n", result);
}
