const std = @import("std");
const disk = @import("disk.zig");
const memory = std.mem;
const heap = std.heap;
const warn = std.debug.warn;
const win32 = @import("bindings/win32.zig");
const windows = std.os.windows;

// LRESULT CALLBACK WindowProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
//     if (message == WM_DESTROY) {
//         // If we receive the destroy message, then quit the program.
//         PostQuitMessage(0);
//         return 0;
//     } else {
//         // We don't handle this message. Use the default handler.
//         return DefWindowProc(window, message, wParam, lParam);
//     }
// }

export fn WindowProcedure(
    window: win32.HWND,
    message: windows.UINT,
    wParam: *windows.UINT,
    lParam: *windows.LONG,
) ?*windows.LONG {
    // WM_DESTROY
    if (message == 2) {
        return null;
    } else {
        return null;
    }
}

export fn WinMain(
    instance: windows.HINSTANCE,
    previousInstance: windows.HINSTANCE,
    commandLine: windows.LPSTR,
    commandShow: windows.INT,
) windows.INT {
    // _ = win32.MessageBoxA(null, c"hello", c"title", 0);
    // warn("wut\n");

    // set up windowClass = WNDCLASS struct, set lpszClassName to a certain class name
    // also reference WindowProcedure in `lpfnWndProc` field
    // WNDCLASS windowClass = {};
    // windowClass.style = CS_HREDRAW | CS_VREDRAW;
    // windowClass.lpfnWndProc = WindowProcedure;
    // windowClass.hInstance = instance;
    // windowClass.lpszClassName = "MyWindowClass";
    // windowClass.hCursor = LoadCursor(NULL, IDC_ARROW);
    // windowClass.hbrBackground = (HBRUSH) (COLOR_WINDOW + 1);
    // RegisterClass(&windowClass);

    // call RegisterClass(&windowClass)
    const window = win32.CreateWindowExA(
        0,
        c"class_name", // set this to the same class name you used before
        c"window_name",
        0,
        0,
        0,
        200,
        200,
        null,
        null,
        instance,
        null,
    );
    win32.ShowWindow(window, commandShow);

    // warn("{}\n", result);

    return 0;
}
