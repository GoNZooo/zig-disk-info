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
    drive_infos: ?[]disk.DriveInfo,
    mouse_x: u32,
    mouse_y: u32,
};

var application_state: ApplicationState = undefined;

var drive_info_arena_allocator = heap.ArenaAllocator.init(heap.page_allocator);

export fn windowProcedure(
    window: win32.c.HWND,
    message: windows.UINT,
    wParam: win32.c.WPARAM,
    lParam: win32.c.LPARAM,
) win32.c.LRESULT {
    var arena_allocator = heap.ArenaAllocator.init(heap.page_allocator);
    const drive_info_allocator = &drive_info_arena_allocator.allocator;
    defer arena_allocator.deinit();
    const allocator = &arena_allocator.allocator;
    switch (message) {
        win32.c.WM_DESTROY => {
            win32.c.PostQuitMessage(0);

            return 0;
        },
        win32.c.WM_CREATE => {
            win32.c.OutputDebugStringA("Window created\n");
        },
        win32.c.WM_MOUSEMOVE => {
            var point: win32.c.POINT = undefined;
            switch (win32.c.GetCursorPos(&point)) {
                0 => {},
                else => {
                    application_state.mouse_x = @intCast(u32, point.x);
                    application_state.mouse_y = @intCast(u32, point.y);
                },
            }
        },
        win32.c.WM_PAINT => {
            win32.c.OutputDebugStringA("PAINT\n");
            var paint_struct = utilities.zeroInit(win32.c.PAINTSTRUCT);
            const device_context = win32.c.BeginPaint(window, &paint_struct);

            const x = paint_struct.rcPaint.left;
            const y = paint_struct.rcPaint.top;
            const height = paint_struct.rcPaint.bottom - paint_struct.rcPaint.top;
            const width = paint_struct.rcPaint.right - paint_struct.rcPaint.left;
            _ = win32.c.PatBlt(device_context, x, y, width, height, WHITENESS);

            _ = win32.c.EndPaint(window, &paint_struct);

            return 0;
        },
        win32.c.WM_KEYUP => {
            const virtual_key_code = wParam;
            const ALPHA_START = 0x30;
            const ALPHA_END = 0x5A;

            switch (virtual_key_code) {
                win32.c.VK_ESCAPE => {
                    win32.c.PostQuitMessage(0);

                    return 0;
                },
                ALPHA_START...ALPHA_END => {
                    switch (virtual_key_code) {
                        'U' => {
                            if (application_state.drive_infos) |drive_infos| {
                                drive_info_allocator.free(drive_infos);
                            }
                            const root_names = disk.enumerateDrives(
                                drive_info_allocator,
                            ) catch |e| {
                                switch (e) {
                                    error.OutOfMemory => @panic("Cannot get disk drives, OOM"),
                                }
                            };
                            const drive_infos = disk.getAllDriveInfos(
                                drive_info_allocator,
                            ) catch |e| {
                                switch (e) {
                                    error.OutOfMemory => @panic("Cannot get free disk space, OOM"),
                                }
                            };
                            application_state.drive_infos = drive_infos;
                            const state_string = fmt.allocPrint(
                                allocator,
                                "state: {}\x00",
                                .{application_state},
                            ) catch unreachable;
                            _ = win32.c.OutputDebugStringA(state_string.ptr);
                            const invalidate_result = win32.c.InvalidateRect(
                                null,
                                null,
                                win32.c.FALSE,
                            );
                        },
                        'I' => {
                            const app_state_copy = application_state;
                            @breakpoint();
                        },
                        else => {},
                    }
                },
                else => {},
            }

            return 0;
        },
        win32.c.WM_LBUTTONUP => {
            const x = win32.lowWord(win32.c.LPARAM, lParam);
            const y = win32.highWord(win32.c.LPARAM, lParam);
            const current_x: c_int = 5;
            var current_y: c_int = 2;
            const height = 20;
            if (application_state.drive_infos) |drive_infos| {
                for (drive_infos) |drive_info| {
                    if (y > current_y and y < (current_y + height)) {
                        const output_string = switch (drive_info.free_disk_space) {
                            .FreeDiskSpace => |r| fmt.allocPrint(
                                allocator,
                                "click: {}\n\x00",
                                .{drive_info.root_name},
                            ) catch unreachable,
                            .UnableToGetDiskInfo => fmt.allocPrint(
                                allocator,
                                "N/A\n\x00",
                                .{},
                            ) catch unreachable,
                        };
                        win32.c.OutputDebugStringA(output_string.ptr);
                        switch (drive_info.free_disk_space) {
                            .FreeDiskSpace => |_| drive_info.openInExplorer(),
                            .UnableToGetDiskInfo => {},
                        }
                    }
                    current_y += height;
                }
            }
        },
        else => {},
    }

    return win32.c.DefWindowProcA(window, message, wParam, lParam);
}

pub export fn WinMain(
    instance: win32.c.HINSTANCE,
    previousInstance: win32.c.HINSTANCE,
    commandLine: windows.LPSTR,
    commandShow: windows.INT,
) windows.INT {
    const WHITE_BRUSH = @ptrCast(win32.c.HBRUSH, @alignCast(8, win32.c.GetStockObject(
        win32.c.WHITE_BRUSH,
    )));

    var arena_allocator = heap.ArenaAllocator.init(heap.direct_allocator);
    defer arena_allocator.deinit();
    const allocator = &arena_allocator.allocator;

    var window_class = utilities.zeroInit(win32.c.WNDCLASS);
    window_class.hInstance = instance;
    window_class.lpszClassName = "di-bitblit";
    window_class.lpfnWndProc = windowProcedure;
    window_class.style = win32.c.CS_HREDRAW | win32.c.CS_VREDRAW | win32.c.CS_OWNDC;
    window_class.hCursor = win32.c.LoadCursorA(null, win32.MAKEINTRESOURCEA(32512));
    window_class.hbrBackground = WHITE_BRUSH;
    const registration = win32.c.RegisterClassA(&window_class);

    // initialize drive info state
    const drive_info_allocator = &drive_info_arena_allocator.allocator;
    const drive_infos = disk.getAllDriveInfos(drive_info_allocator) catch |e| {
        switch (e) {
            error.OutOfMemory => @panic("Cannot allocate memory, OOM"),
        }
    };
    application_state.drive_infos = drive_infos;

    const window = win32.c.CreateWindowExA(
        0,
        "di-bitblit",
        "di-bitblit",
        win32.c.WS_OVERLAPPEDWINDOW | win32.c.WS_VISIBLE,
        50,
        50,
        640,
        480,
        null,
        null,
        instance,
        null,
    );
    var msg = utilities.zeroInit(win32.c.MSG);
    var received_message = win32.c.GetMessageA(&msg, null, 0, 0);
    while (received_message != 0) : (received_message = win32.c.GetMessageA(&msg, null, 0, 0)) {
        const translated = win32.c.TranslateMessage(&msg);
        const dispatch_result = win32.c.DispatchMessageA(&msg);
    }

    return 0;
}

const WHITENESS = 0x00ff0062;
