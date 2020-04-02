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
    mouse_x: u32,
    mouse_y: u32,
};

var application_state: ApplicationState = undefined;

var disk_info_arena_allocator = heap.ArenaAllocator.init(heap.page_allocator);

export fn windowProcedure(
    window: win32.c.HWND,
    message: windows.UINT,
    wParam: win32.c.WPARAM,
    lParam: win32.c.LPARAM,
) win32.c.LRESULT {
    var arena_allocator = heap.ArenaAllocator.init(heap.page_allocator);
    const disk_info_allocator = &disk_info_arena_allocator.allocator;
    defer arena_allocator.deinit();
    const allocator = &arena_allocator.allocator;
    switch (message) {
        win32.c.WM_DESTROY => {
            win32.c.OutputDebugStringA("Window destroyed\n");
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

            var client_rect = utilities.zeroInit(win32.c.RECT);
            _ = win32.c.GetClientRect(window, &client_rect);
            const rect_string = fmt.allocPrint(allocator, "{}\x00", .{client_rect}) catch unreachable;
            _ = win32.c.OutputDebugStringA(rect_string.ptr);
            _ = win32.c.SetBkMode(device_context, win32.c.OPAQUE);

            const black_pen = @intCast(c_ulong, @ptrToInt(win32.c.GetStockObject(win32.c.BLACK_PEN)));
            _ = win32.c.SetDCPenColor(device_context, black_pen);
            if (application_state.disk_data) |data| {
                const current_x: c_int = 5;
                var current_y: c_int = 2;
                for (data) |result| {
                    const result_string = switch (result) {
                        .FreeDiskSpace => |r| fmt.allocPrint(
                            allocator,
                            "{}: {d:>9.3} GiB / {d:>9.3} GiB\x00",
                            .{
                                r.root_name,
                                r.freeDiskSpaceInGibiBytes(),
                                r.diskSpaceInGibiBytes(),
                            },
                        ) catch |e| block: {
                            break :block switch (e) {
                                error.OutOfMemory => @panic("OOM"),
                            };
                        },
                        .UnableToGetDiskInfo => |root_name| fmt.allocPrint(
                            allocator,
                            "{}: Unable to get disk info\x00",
                            .{root_name},
                        ) catch |e| block: {
                            break :block switch (e) {
                                error.OutOfMemory => @panic("OOM"),
                            };
                        },
                    };
                    const text_out_result = win32.c.TextOutA(
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
                            if (application_state.disk_data) |data| {
                                disk_info_allocator.free(data);
                            }
                            const root_names = disk.enumerateDrives(disk_info_allocator) catch |e| {
                                switch (e) {
                                    error.OutOfMemory => @panic("Cannot get disk drives, OOM"),
                                }
                            };
                            const free_disk_space_results = disk.getFreeDiskSpace(
                                disk_info_allocator,
                                root_names,
                            ) catch |e| {
                                switch (e) {
                                    error.OutOfMemory => @panic("Cannot get free disk space, OOM"),
                                }
                            };
                            application_state.disk_data = free_disk_space_results;
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

                            if (invalidate_result != 0) {
                                // @breakpoint();
                                win32.c.OutputDebugStringA("Invalidated rect\n");
                            }
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
            const x = lParam & 0xffff;
            const y = (lParam & 0xffff0000) >> 16;
            const current_x: c_int = 5;
            var current_y: c_int = 2;
            const height = 20;
            if (application_state.disk_data) |data| {
                for (data) |result| {
                    if (y > current_y and y < (current_y + height)) {
                        const output_string = switch (result) {
                            .FreeDiskSpace => |r| fmt.allocPrint(
                                allocator,
                                "click: {}\n\x00",
                                .{r.root_name},
                            ) catch unreachable,
                            .UnableToGetDiskInfo => fmt.allocPrint(
                                allocator,
                                "N/A\n\x00",
                                .{},
                            ) catch unreachable,
                        };
                        win32.c.OutputDebugStringA(output_string.ptr);
                        switch (result) {
                            .FreeDiskSpace => |r| {
                                _ = win32.c.ShellExecute(
                                    null,
                                    "open",
                                    r.root_name[0..],
                                    null,
                                    null,
                                    win32.c.SW_SHOWDEFAULT,
                                );
                            },
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
    window_class.lpszClassName = "disk-info";
    window_class.lpfnWndProc = windowProcedure;
    window_class.style = win32.c.CS_HREDRAW | win32.c.CS_VREDRAW;
    window_class.hCursor = win32.c.LoadCursorA(null, win32.MAKEINTRESOURCEA(32512));
    window_class.hbrBackground = WHITE_BRUSH;
    const registration = win32.c.RegisterClassA(&window_class);
    const disk_info_allocator = &disk_info_arena_allocator.allocator;
    const root_names = disk.enumerateDrives(disk_info_allocator) catch |e| {
        switch (e) {
            error.OutOfMemory => @panic("Cannot allocate memory, OOM"),
        }
    };
    const free_disk_space_results = disk.getFreeDiskSpace(
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
        "disk-info",
        "disk-info",
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
    const show_window = win32.c.ShowWindow(window, 1);
    var msg = utilities.zeroInit(win32.c.MSG);
    var received_message = win32.c.GetMessageA(&msg, null, 0, 0);
    while (received_message != 0) : (received_message = win32.c.GetMessageA(&msg, null, 0, 0)) {
        const translated = win32.c.TranslateMessage(&msg);
        const dispatch_result = win32.c.DispatchMessageA(&msg);
    }

    return 0;
}
