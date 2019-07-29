const std = @import("std");
const disk = @import("disk.zig");
const mem = std.mem;
const heap = std.heap;
const warn = std.debug.warn;
const win32 = @import("bindings/win32.zig");
const windows = std.os.windows;
const fmt = std.fmt;

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

export fn windowProcedure(
    window: win32.HWND,
    message: windows.UINT,
    wParam: win32.WPARAM,
    lParam: win32.LPARAM,
) win32.LRESULT {
    return win32.DefWindowProcA(window, message, wParam, lParam);
}

export fn WinMain(
    instance: windows.HINSTANCE,
    previousInstance: windows.HINSTANCE,
    commandLine: windows.LPSTR,
    commandShow: windows.INT,
) windows.INT {
    const allocator = &heap.ArenaAllocator.init(heap.direct_allocator).allocator;

    // set up windowClass = WNDCLASS struct, set lpszClassName to a certain class name
    // also reference WindowProcedure in `lpfnWndProc` field
    // WNDCLASS windowClass = {};
    // windowClass.style = CS_HREDRAW | CS_VREDRAW;
    // windowClass.lpfnWndProc = WindowProcedure;
    // windowClass.hInstance = instance;
    // windowClass.lpszClassName = "MyWindowClass";
    // windowClass.hCursor = LoadCursor(NULL, IDC_ARROW);
    // windowClass.hbrBackground = (HBRUSH) (COLOR_WINDOW + 1);
    var windowClass = win32.WNDCLASS{
        .instance = instance,
        .className = c"disk-info",
        .windowProcedure = windowProcedure,
    };
    _ = win32.RegisterClassA(&windowClass);

    const windowClassString = fmt.allocPrint(allocator, "{}\x00", windowClass) catch unreachable;
    const windowClassStringCLength = fmt.allocPrint(
        allocator,
        "{}\x00",
        windowClassString.len,
    ) catch unreachable;
    _ = win32.MessageBoxA(null, windowClassString.ptr, c"window class", 0);
    _ = win32.MessageBoxA(null, windowClassStringCLength.ptr, c"string length", 0);

    // call RegisterClass(&windowClass)
    // const window = win32.CreateWindowExA(
    //     0,
    //     c"class_name", // set this to the same class name you used before
    //     c"window_name",
    //     0,
    //     0,
    //     0,
    //     200,
    //     200,
    //     null,
    //     null,
    //     instance,
    //     null,
    // );
    // win32.ShowWindow(window, commandShow);

    // warn("{}\n", result);

    return 0;
}

// pub fn main() anyerror!void {
//     const allocator = &heap.ArenaAllocator.init(heap.direct_allocator).allocator;
//     const windowClass = win32.WNDCLASS{};
//     const windowClassString = fmt.allocPrint(allocator, "{}", windowClass) catch unreachable;
//     warn("{}\nlen: {}", windowClassString, windowClassString.len);
// }
