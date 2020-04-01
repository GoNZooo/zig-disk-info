const std = @import("std");

const State = struct {
    hot: ?Id,
    active: ?Id,
};

const Id = struct {
    primary: PrimaryId,
    secondary: SecondaryId = 0,

    pub fn isEqual(self: Id, id: Id) bool {
        return mem.eql(u8, self.primary, id.primary) and self.secondary == id.secondary;
    }
};

const PrimaryId = []const u8;
const SecondaryId = u32;
