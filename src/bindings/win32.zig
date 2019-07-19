const std = @import("std");
const windows = std.os.windows;

pub const HWND = windows.HANDLE;
const HMENU = windows.HANDLE;
pub const HINSTANCE = windows.HANDLE;

// pub const WNDCLASS = struct {
//     style: windows.UINT = 0,
//     windowProcedure: windows.WNDPROC = undefined,
//     extraClassBytes: i32 = 0,
//     extraWindowBytes: i32 = 0,
//     instance:
// };

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

pub extern "user32" stdcallcc fn CreateWindowEx(
    exStyle: windows.DWORD,
    className: windows.LPCSTR,
    windowName: windows.LPCSTR,
    style: windows.DWORD,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    windowParent: HWND,
    menu: HMENU,
    instance: windows.HINSTANCE,
    parameters: windows.LPVOID,
) HWND;
