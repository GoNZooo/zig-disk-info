const std = @import("std");
const disk = @import("./disk.zig");
const mem = std.mem;
const heap = std.heap;
const warn = std.debug.warn;
const win32 = @import("win32");
const windows = std.os.windows;
const fmt = std.fmt;
const utilities = @import("./utilities.zig");

const ApplicationState = struct {
    disk_data: ?[]disk.FreeDiskSpaceResult,
};

var application_state: ApplicationState = undefined;

const xinput = @import("bindings/xinput.zig");

const XInputGetStateProcType = extern fn (
    user_index: windows.DWORD,
    state: *xinput.XINPUT_STATE,
) windows.DWORD;
var XInputGetStateProc: ?XInputGetStateProcType = null;

var disk_info_arena_allocator = heap.ArenaAllocator.init(heap.direct_allocator);

export fn windowProcedure(
    window: win32.c.HWND,
    message: windows.UINT,
    wParam: win32.c.WPARAM,
    lParam: win32.c.LPARAM,
) win32.c.LRESULT {
    var arena_allocator = heap.ArenaAllocator.init(heap.direct_allocator);
    const disk_info_allocator = &disk_info_arena_allocator.allocator;
    defer arena_allocator.deinit();
    const allocator = &arena_allocator.allocator;
    // switch (message) {
    //     win32.c.WM_DESTROY => {
    //         win32.c.OutputDebugStringA(c"Window destroyed\n");
    //         win32.c.PostQuitMessage(0);

    //         return 0;
    //     },
    //     win32.c.WM_CREATE => {
    //         win32.c.OutputDebugStringA(c"Window created\n");
    //     },
    //     else => {
    //         const message_string = fmt.allocPrint(
    //             allocator,
    //             "unknown message, message: 0x{x} ({})\twParam: {}\tlParam: {}\n\x00",
    //             message,
    //             message,
    //             wParam,
    //             lParam,
    //         ) catch unreachable;
    //         win32.c.OutputDebugStringA(message_string.ptr);
    //     },
    // }
    switch (message) {
        win32.c.WM_DESTROY => {
            win32.c.OutputDebugStringA(c"Window destroyed\n");
            win32.c.PostQuitMessage(0);

            return 0;
        },
        win32.c.WM_CREATE => {
            win32.c.OutputDebugStringA(c"Window created\n");
            // const subsystem_string = fmt.allocPrint(
            //     allocator,
            //     "subsystem: {}\n\x00",
            //     windows.subsystem,
            // ) catch unreachable;
            // _ = win32.c.MessageBoxA(null, subsystem_string.ptr, c"subsystem", 0);
        },
        win32.c.WM_PAINT => {
            win32.c.OutputDebugStringA(c"PAINT\n");
            var paint_struct = utilities.zeroInit(win32.c.PAINTSTRUCT);
            var device_context = win32.c.BeginPaint(window, &paint_struct);

            var client_rect = utilities.zeroInit(win32.c.RECT);
            _ = win32.c.GetClientRect(window, &client_rect);
            _ = win32.c.SetBkMode(
                device_context,
                @intCast(c_int, @ptrToInt(win32.c.GetStockObject(win32.c.WHITE_BRUSH))),
            );

            var black_pen = @intCast(c_ulong, @ptrToInt(win32.c.GetStockObject(win32.c.BLACK_PEN)));
            _ = win32.c.SetDCPenColor(device_context, black_pen);
            if (application_state.disk_data) |data| {
                const current_x: c_int = 5;
                var current_y: c_int = 2;
                for (data) |result| {
                    var result_string = switch (result) {
                        .FreeDiskSpace => |r| fmt.allocPrint(
                            allocator,
                            "{}: {d:>9.3} GB / {d:>9.3} GB\x00",
                            r.root_name,
                            r.freeDiskSpaceInGigaBytes(),
                            r.diskSpaceInGigaBytes(),
                        ) catch |e| block: {
                            break :block switch (e) {
                                error.OutOfMemory => "OOM error\n\x00"[0..],
                            };
                        },
                        .UnableToGetDiskInfo => |root_name| fmt.allocPrint(
                            allocator,
                            "UnableToGetDiskInfo: {}\x00",
                            root_name,
                        ) catch |e| block: {
                            break :block switch (e) {
                                error.OutOfMemory => "OOM error\n\x00"[0..],
                            };
                        },
                    };
                    // _ = win32.c.MessageBoxA(null, result_string.ptr, c"result_string", 0);
                    var text_out_result = win32.c.TextOutA(
                        device_context,
                        current_x,
                        current_y,
                        result_string[0..].ptr,
                        @intCast(c_int, result_string.len),
                    );
                    _ = win32.c.MoveToEx(
                        device_context,
                        0,
                        current_y,
                        null,
                    );
                    current_y += 20;
                }
            }

            _ = win32.c.EndPaint(window, &paint_struct);

            return 0;
        },
        win32.c.WM_KEYDOWN => {
            const virtual_key_code = wParam;
            switch (virtual_key_code) {
                win32.c.VK_ESCAPE => {
                    win32.c.PostQuitMessage(0);

                    return 0;
                },
                else => {
                    const keyup_string = fmt.allocPrint(
                        allocator,
                        "WM_KEYDOWN: {}\n\x00",
                        virtual_key_code,
                    ) catch |e| block: {
                        break :block switch (e) {
                            error.OutOfMemory => "OOM error\n\x00"[0..],
                        };
                    };
                    win32.c.OutputDebugStringA(keyup_string.ptr);
                },
            }
        },
        win32.c.WM_KEYUP => {
            const virtual_key_code = wParam;
            switch (virtual_key_code) {
                win32.c.VK_ESCAPE => {
                    win32.c.PostQuitMessage(0);

                    return 0;
                },
                0x30...0x5A => {
                    switch (virtual_key_code) {
                        'U' => {
                            if (application_state.disk_data) |data| {
                                disk_info_allocator.free(data);
                            }
                            var root_names = disk.enumerateDrives(disk_info_allocator) catch |e| {
                                switch (e) {
                                    error.OutOfMemory => @panic("Cannot get disk drives, OOM"),
                                }
                            };
                            var free_disk_space_results = disk.getFreeDiskSpace(
                                disk_info_allocator,
                                root_names,
                            ) catch |e| {
                                switch (e) {
                                    error.OutOfMemory => @panic("Cannot get free disk space, OOM"),
                                }
                            };
                            application_state.disk_data = free_disk_space_results;
                            var invalidate_result = win32.c.InvalidateRect(
                                window,
                                null,
                                win32.c.TRUE,
                            );
                        },
                        'I' => {
                            var app_state_copy = application_state;
                            @breakpoint();
                        },
                        else => {},
                    }
                },
                else => {
                    const keyup_string = fmt.allocPrint(
                        allocator,
                        "WM_KEYUP: {}\n\x00",
                        virtual_key_code,
                    ) catch unreachable;
                    win32.c.OutputDebugStringA(keyup_string.ptr);
                },
            }
        },
        win32.c.WM_CHAR => {
            const virtual_key_code = wParam;
            switch (virtual_key_code) {
                win32.c.VK_ESCAPE => {
                    win32.c.PostQuitMessage(0);

                    return 0;
                },
                else => {
                    const keyup_string = fmt.allocPrint(
                        allocator,
                        "WM_CHAR: {}\n\x00",
                        virtual_key_code,
                    ) catch unreachable;
                    win32.c.OutputDebugStringA(keyup_string.ptr);
                },
            }
        },
        win32.c.WM_MOVE => {
            win32.c.OutputDebugStringA(c"MOVE\n");
        },
        win32.c.WM_SIZE => {
            win32.c.OutputDebugStringA(c"SIZE\n");
        },
        win32.c.WM_GETMINMAXINFO => {
            win32.c.OutputDebugStringA(c"GETMINMAXINFO\n");
        },
        win32.c.WM_WINDOWPOSCHANGING => {
            win32.c.OutputDebugStringA(c"WINDOWPOSCHANGING\n");
        },
        win32.c.WM_WINDOWPOSCHANGED => {
            win32.c.OutputDebugStringA(c"WINDOWPOSCHANGED\n");
        },
        win32.c.WM_GETICON => {
            win32.c.OutputDebugStringA(c"GETICON\n");
        },
        win32.c.WM_NCCREATE => {
            win32.c.OutputDebugStringA(c"NCCREATE\n");
        },
        win32.c.WM_NCCALCSIZE => {
            win32.c.OutputDebugStringA(c"NCCALCSIZE\n");
        },
        else => {
            const message_string = fmt.allocPrint(
                allocator,
                "unknown message, message: 0x{x} ({})\twParam: {}\tlParam: {}\n\x00",
                message,
                message,
                wParam,
                lParam,
            ) catch unreachable;
            win32.c.OutputDebugStringA(message_string.ptr);
        },
    }

    return win32.c.DefWindowProcA(window, message, wParam, lParam);
}

pub export fn WinMain(
    instance: win32.c.HINSTANCE,
    previousInstance: win32.c.HINSTANCE,
    commandLine: windows.LPSTR,
    commandShow: windows.INT,
) windows.INT {
    var arena_allocator = heap.ArenaAllocator.init(heap.direct_allocator);
    defer arena_allocator.deinit();
    const allocator = &arena_allocator.allocator;

    // set up windowClass = WNDCLASS struct, set lpszClassName to a certain class name
    // also reference WindowProcedure in `lpfnWndProc` field
    // WNDCLASS windowClass = {};
    // windowClass.style = CS_HREDRAW | CS_VREDRAW;
    // windowClass.lpfnWndProc = WindowProcedure;
    // windowClass.hInstance = instance;
    // windowClass.lpszClassName = "MyWindowClass";
    // windowClass.hCursor = LoadCursor(NULL, IDC_ARROW);
    // windowClass.hbrBackground = (HBRUSH) (COLOR_WINDOW + 1);
    // @breakpoint();
    var window_class = utilities.zeroInit(win32.c.WNDCLASS);
    window_class.hInstance = instance;
    window_class.lpszClassName = c"disk-info";
    window_class.lpfnWndProc = windowProcedure;
    window_class.style = win32.c.CS_HREDRAW | win32.c.CS_VREDRAW;
    window_class.hCursor = win32.c.LoadCursorA(null, win32.MAKEINTRESOURCEA(32512));
    window_class.hbrBackground = @intToPtr(win32.c.HBRUSH, 6);
    const registration = win32.c.RegisterClassA(&window_class);
    // const registration_string = fmt.allocPrint(
    //     allocator,
    //     "registration: {}\n\x00",
    //     registration,
    // ) catch unreachable;
    // _ = win32.c.MessageBoxA(null, registration_string.ptr, c"registration", 0);
    const disk_info_allocator = &disk_info_arena_allocator.allocator;
    var root_names = disk.enumerateDrives(disk_info_allocator) catch |e| {
        switch (e) {
            error.OutOfMemory => @panic("Cannot allocate memory, OOM"),
        }
    };
    var free_disk_space_results = disk.getFreeDiskSpace(
        disk_info_allocator,
        root_names,
    ) catch |e| {
        switch (e) {
            error.OutOfMemory => @panic("Cannot allocate memory, OOM"),
        }
    };
    application_state.disk_data = free_disk_space_results;

    const window = win32.c.CreateWindowExA(
        0,
        c"disk-info",
        c"disk-info",
        win32.c.WS_OVERLAPPEDWINDOW,
        30,
        30,
        250,
        @intCast(c_int, free_disk_space_results.len * 20) + 40,
        null,
        null,
        instance,
        null,
    );
    // const window_string = fmt.allocPrint(allocator, "{}\x00", window) catch unreachable;
    // _ = win32.c.MessageBoxA(null, window_string.ptr, c"window", 0);
    const show_window = win32.c.ShowWindow(window, 1);
    // const show_window_string = fmt.allocPrint(
    //     allocator,
    //     "show_window: {}\n\x00",
    //     show_window,
    // ) catch unreachable;
    // _ = win32.c.MessageBoxA(null, show_window_string.ptr, c"show_window", 0);

    var msg = utilities.zeroInit(win32.c.MSG);
    var received_message = win32.c.GetMessageA(&msg, null, 0, 0);
    while (received_message != 0) : (received_message = win32.c.GetMessageA(&msg, null, 0, 0)) {
        const translated = win32.c.TranslateMessage(&msg);
        const dispatch_result = win32.c.DispatchMessageA(&msg);
        // const message_string = fmt.allocPrint(
        //     allocator,
        //     "msg: {} | {} | {}\n\x00",
        //     msg,
        //     translated,
        //     dispatch_result,
        // ) catch unreachable;
        // win32.c.OutputDebugStringA(message_string.ptr);
    }

    return 0;
}
