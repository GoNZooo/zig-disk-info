const mem = @import("std").mem;

pub fn zeroInit(comptime T: type) T {
    var bytes = [_]u8{0} ** @sizeOf(T);
    return mem.bytesToValue(T, bytes);
}

pub fn voidPointerTo(comptime T: type, ptr: ?*c_void) T {
    return @intToPtr(T, @ptrToInt(ptr));
}
