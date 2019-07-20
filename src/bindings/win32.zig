const std = @import("std");
const windows = std.os.windows;

pub const HWND = windows.HANDLE;
const HMENU = windows.HANDLE;
pub const HINSTANCE = windows.HANDLE;

pub const WNDCLASS = struct {
    style: windows.UINT = 0,
    windowProcedure: ?windows.WNDPROC = undefined,
    extraClassBytes: windows.INT = 0,
    extraWindowBytes: windows.INT = 0,
    instance: HINSTANCE,
};

pub extern "kernel32" stdcallcc fn GetDiskFreeSpaceA(
    root_path_name: windows.LPCSTR,
    sectors_per_cluster: windows.LPDWORD,
    bytes_per_sector: windows.LPDWORD,
    number_of_free_clusters: windows.LPDWORD,
    total_number_of_clusters: windows.LPDWORD,
) windows.BOOL;

pub extern "kernel32" stdcallcc fn GetDriveTypeA(
    root_path_name: windows.LPCSTR,
) windows.UINT;

pub extern "kernel32" stdcallcc fn GetLogicalDrives() windows.DWORD;

pub extern "kernel32" stdcallcc fn GetLogicalDriveStringsA(
    buffer_length: windows.DWORD,
    buffer: windows.LPSTR,
) windows.DWORD;

pub extern "kernel32" stdcallcc fn GetLogicalDriveStringsW(
    buffer_length: windows.DWORD,
    buffer: windows.LPWSTR,
) windows.DWORD;

pub extern "user32" stdcallcc fn CreateWindowExA(
    exStyle: windows.DWORD,
    className: windows.LPCSTR,
    windowName: windows.LPCSTR,
    style: windows.DWORD,
    x: windows.INT,
    y: windows.INT,
    width: windows.INT,
    height: windows.INT,
    windowParent: ?HWND,
    menu: ?HMENU,
    instance: windows.HINSTANCE,
    parameters: ?windows.LPVOID,
) HWND;

pub extern "user32" stdcallcc fn ShowWindow(windowHandle: HWND, commandShow: windows.INT) void;

pub extern "user32" stdcallcc fn MessageBoxA(
    hWnd: ?HWND,
    lpText: ?windows.LPCTSTR,
    lpCaption: ?windows.LPCTSTR,
    uType: windows.UINT,
) c_int;
