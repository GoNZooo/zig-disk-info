const win32 = @import("bindings/win32.zig");

test "`CreateWindowEx`" {
    const class_name = "className";
    const window_name = "windowName";
    _ = win32.CreateWindowEx(
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
    );
}
