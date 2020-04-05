const std = @import("std");
const windows = std.os.windows;
const memory = std.mem;
const ArenaAllocator = std.heap.ArenaAllocator;
const assert = std.debug.assert;
const warn = std.debug.warn;
const expect = std.testing.expect;
const win32 = @import("win32");
const time = std.time;
const debug = std.debug;

pub const DriveType = enum {
    Unknown = 0,
    NoRootDirectory = 1,
    Removable = 2,
    Fixed = 3,
    Remote = 4,
    CDROM = 5,
    RAMdisk = 6,
};

pub const RootPathName = [4]u8;

const FreeDiskSpaceData = struct {
    root_name: RootPathName,
    sectors_per_cluster: u32,
    bytes_per_sector: u32,
    number_of_free_clusters: u32,
    total_number_of_clusters: u32,

    pub fn sectorSizeInBytes(self: FreeDiskSpaceData) u64 {
        return self.bytes_per_sector * self.sectors_per_cluster;
    }

    pub fn freeDiskSpaceInBytes(self: FreeDiskSpaceData) u64 {
        return sectorSizeInBytes(self) * @as(u64, self.number_of_free_clusters);
    }

    pub fn diskSpaceInBytes(self: FreeDiskSpaceData) u64 {
        return sectorSizeInBytes(self) * @as(u64, self.total_number_of_clusters);
    }

    pub fn freeDiskSpaceInKiloBytes(self: FreeDiskSpaceData) f64 {
        return @intToFloat(f64, self.freeDiskSpaceInBytes()) / 1000.0;
    }

    pub fn diskSpaceInKiloBytes(self: FreeDiskSpaceData) f64 {
        return @intToFloat(f64, self.diskSpaceInBytes()) / 1000.0;
    }

    pub fn freeDiskSpaceInMegaBytes(self: FreeDiskSpaceData) f64 {
        return @intToFloat(f64, self.freeDiskSpaceInBytes()) / (1000.0 * 1000.0);
    }

    pub fn diskSpaceInMegaBytes(self: FreeDiskSpaceData) f64 {
        return @intToFloat(f64, self.diskSpaceInBytes()) / (1000.0 * 1000.0);
    }

    pub fn freeDiskSpaceInGigaBytes(self: FreeDiskSpaceData) f64 {
        return @intToFloat(f64, self.freeDiskSpaceInBytes()) / (1000.0 * 1000.0 * 1000.0);
    }

    pub fn diskSpaceInGigaBytes(self: FreeDiskSpaceData) f64 {
        return @intToFloat(f64, self.diskSpaceInBytes()) / (1000.0 * 1000.0 * 1000.0);
    }

    pub fn freeDiskSpaceInKibiBytes(self: FreeDiskSpaceData) f64 {
        return @intToFloat(f64, self.freeDiskSpaceInBytes()) / 1024.0;
    }

    pub fn diskSpaceInKibiBytes(self: FreeDiskSpaceData) f64 {
        return @intToFloat(f64, self.diskSpaceInBytes()) / 1024.0;
    }

    pub fn freeDiskSpaceInMebiBytes(self: FreeDiskSpaceData) f64 {
        return @intToFloat(f64, self.freeDiskSpaceInBytes()) / (1024.0 * 1024.0);
    }

    pub fn diskSpaceInMebiBytes(self: FreeDiskSpaceData) f64 {
        return @intToFloat(f64, self.diskSpaceInBytes()) / (1024.0 * 1024.0);
    }

    pub fn freeDiskSpaceInGibiBytes(self: FreeDiskSpaceData) f64 {
        return @intToFloat(f64, self.freeDiskSpaceInBytes()) / (1024.0 * 1024.0 * 1024.0);
    }

    pub fn diskSpaceInGibiBytes(self: FreeDiskSpaceData) f64 {
        return @intToFloat(f64, self.diskSpaceInBytes()) / (1024.0 * 1024.0 * 1024.0);
    }

    pub fn openInExplorer(self: FreeDiskSpaceData) void {
        _ = win32.c.ShellExecute(
            null,
            "open",
            self.root_name[0..],
            null,
            null,
            win32.c.SW_SHOWDEFAULT,
        );
    }
};

pub const FreeDiskSpaceResult = union(enum) {
    FreeDiskSpace: FreeDiskSpaceData,
    UnableToGetDiskInfo: RootPathName,
};

test "`getDriveType`" {
    const drives = try enumerateDrives(std.heap.direct_allocator);
    const first_drive = getDriveType(&drives[0]);
    expect(first_drive == DriveType.Fixed);
}

pub fn getDriveType(root_path_name: [*]const u8) DriveType {
    return @intToEnum(DriveType, @intCast(u3, win32.c.GetDriveTypeA(root_path_name)));
}

test "`enumerateDrives`" {
    var arena_allocator = ArenaAllocator.init(std.heap.direct_allocator);
    defer arena_allocator.deinit();
    const allocator = &arena_allocator.allocator;
    const result = try enumerateDrives(allocator);
    expect(result.len != 0);
}

test "`enumerateDrives` with direct allocator" {
    const result = try enumerateDrives(std.heap.direct_allocator);
    expect(result.len != 0);
}

pub fn enumerateDrives(allocator: *memory.Allocator) error{OutOfMemory}![]RootPathName {
    var logical_drives_mask = win32.c.GetLogicalDrives();
    const logical_drive_bytes = try allocator.alloc(
        [4]u8,
        @popCount(@TypeOf(logical_drives_mask), logical_drives_mask),
    );
    errdefer allocator.free(logical_drive_bytes);
    var letter: u8 = 'A';
    var index: u8 = 0;
    while (logical_drives_mask != 0) : (logical_drives_mask >>= 1) {
        if ((logical_drives_mask & 1) == 1) {
            logical_drive_bytes[index][0] = letter;
            logical_drive_bytes[index][1] = ':';
            logical_drive_bytes[index][2] = '\\';
            logical_drive_bytes[index][3] = 0;
            index += 1;
        }
        letter += 1;
    }

    return logical_drive_bytes;
}

test "`getFreeDiskSpace` doesn't leak memory" {
    const allocator = std.heap.page_allocator;
    const drives = try enumerateDrives(allocator);

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        debug.warn("\nRunning: {}\n", .{i});
        var j: usize = 0;
        while (j < 10000) : (j += 1) {
            const disk_data = try getFreeDiskSpace(allocator, drives);
            allocator.free(disk_data);
        }
        time.sleep(10000000);
    }
}

test "calculations for free disk space in 'bytes' make sense" {
    const allocator = std.heap.direct_allocator;
    const result = try enumerateDrives(allocator);
    const free_disk_space_entries = try getFreeDiskSpace(allocator, result);
    var at_least_one_ok = false;
    expect(free_disk_space_entries.len != 0);
    for (free_disk_space_entries) |free_disk_space_entry| {
        switch (free_disk_space_entry) {
            .FreeDiskSpace => |free_disk_space| {
                const free_space_bytes = free_disk_space.freeDiskSpaceInBytes();
                const free_space_kilobytes = free_disk_space.freeDiskSpaceInKiloBytes();
                const free_space_megabytes = free_disk_space.freeDiskSpaceInMegaBytes();
                const free_space_gigabytes = free_disk_space.freeDiskSpaceInGigaBytes();

                expectApproximatelyEqual(
                    0.1,
                    free_space_kilobytes,
                    @intToFloat(f64, free_space_bytes) / 1000.0,
                );
                expectApproximatelyEqual(0.1, free_space_megabytes, free_space_kilobytes / 1000.0);
                expectApproximatelyEqual(0.1, free_space_gigabytes, free_space_megabytes / 1000.0);
                at_least_one_ok = true;
            },
            .UnableToGetDiskInfo => {},
        }
    }
    expect(at_least_one_ok);
}

test "calculations for free disk space in '{ki,me,gi}bibytes' make sense" {
    const allocator = std.heap.direct_allocator;
    const result = try enumerateDrives(allocator);
    const free_disk_space_entries = try getFreeDiskSpace(allocator, result);
    expect(free_disk_space_entries.len != 0);
    var at_least_one_ok = false;
    const free_data = FreeDiskSpaceData{
        .root_name = [4]u8{ 'C', ':', '\\', '\\' },
        .sectors_per_cluster = 1,
        .bytes_per_sector = 1000,
        .number_of_free_clusters = 1,
        .total_number_of_clusters = 1,
    };

    const free_bytes = free_data.freeDiskSpaceInBytes();
    const free_kibibytes = free_data.freeDiskSpaceInKibiBytes();
    const free_mebibytes = free_data.freeDiskSpaceInMebiBytes();
    const free_gibibytes = free_data.freeDiskSpaceInGibiBytes();
    expectApproximatelyEqual(0.1, free_kibibytes, @intToFloat(f64, free_bytes) / 1024.0);
    expectApproximatelyEqual(0.1, free_mebibytes, free_kibibytes / 1024.0);
    expectApproximatelyEqual(0.1, free_gibibytes, free_mebibytes / 1024.0);

    for (free_disk_space_entries) |free_disk_space_entry| {
        switch (free_disk_space_entry) {
            .FreeDiskSpace => |free_disk_space| {
                const free_space_bytes = free_disk_space.freeDiskSpaceInBytes();
                const free_space_kibibytes = free_disk_space.freeDiskSpaceInKibiBytes();
                const free_space_mebibytes = free_disk_space.freeDiskSpaceInMebiBytes();
                const free_space_gibibytes = free_disk_space.freeDiskSpaceInGibiBytes();

                expectApproximatelyEqual(
                    0.1,
                    free_space_kibibytes,
                    @intToFloat(f64, free_space_bytes) / 1024.0,
                );
                expectApproximatelyEqual(0.1, free_space_mebibytes, free_space_kibibytes / 1024.0);
                expectApproximatelyEqual(0.1, free_space_gibibytes, free_space_mebibytes / 1024.0);
                at_least_one_ok = true;
            },
            .UnableToGetDiskInfo => {},
        }
    }
    expect(at_least_one_ok);
}

pub fn getFreeDiskSpace(
    allocator: *memory.Allocator,
    root_path_names: []RootPathName,
) error{OutOfMemory}![]FreeDiskSpaceResult {
    const disk_data = try allocator.alloc(FreeDiskSpaceResult, root_path_names.len);
    errdefer allocator.free(disk_data);

    for (root_path_names) |name, i| {
        var sectors_per_cluster: win32.c.ULONG = undefined;
        var bytes_per_sector: win32.c.ULONG = undefined;
        var number_of_free_clusters: win32.c.ULONG = undefined;
        var total_number_of_clusters: win32.c.ULONG = undefined;
        const result = win32.c.GetDiskFreeSpaceA(
            &name,
            &sectors_per_cluster,
            &bytes_per_sector,
            &number_of_free_clusters,
            &total_number_of_clusters,
        );
        switch (result) {
            0 => disk_data[i] = FreeDiskSpaceResult{ .UnableToGetDiskInfo = name },
            else => disk_data[i] = FreeDiskSpaceResult{
                .FreeDiskSpace = FreeDiskSpaceData{
                    .root_name = name,
                    .sectors_per_cluster = sectors_per_cluster,
                    .bytes_per_sector = bytes_per_sector,
                    .number_of_free_clusters = number_of_free_clusters,
                    .total_number_of_clusters = total_number_of_clusters,
                },
            },
        }
    }

    return disk_data;
}

fn expectApproximatelyEqual(tolerance: f64, a: f64, b: f64) void {
    const diff = @fabs(a - b);
    expect(diff < tolerance);
}
