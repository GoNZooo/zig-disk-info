const std = @import("std");

const State = struct {
    hot: Id,
    active: Id,
};

const Id = []const u8;
