const std = @import("std");
const mem = std.mem;
const testing = std.testing;

pub const State = struct {
    renderers: []const Renderer,
    mouse: Mouse,
    hot: ?Id = null,
    active: ?Id = null,
};

pub fn makeId(primary: PrimaryId, secondary: SecondaryId) Id {
    return Id{ .primary = primary, .secondary = secondary };
}

pub const Id = struct {
    primary: PrimaryId,
    secondary: SecondaryId = 0,

    pub fn isEqual(self: Id, id: Id) bool {
        return mem.eql(u8, self.primary, id.primary) and self.secondary == id.secondary;
    }
};

pub const Renderer = struct {
    button: fn (rect: Rect, text: []const u8) void,
};

pub const Mouse = struct {
    x: u32,
    y: u32,
    left_up: bool = false,
    middle_up: bool = false,
    right_up: bool = false,
    left_down: bool = false,
    middle_down: bool = false,
    right_down: bool = false,

    pub fn isInRect(self: @This(), rect: Rect) bool {
        const rect_x_lower_bound = rect.x;
        const rect_x_upper_bound = rect.x + rect.w;
        const rect_y_lower_bound = rect.y;
        const rect_y_upper_bound = rect.y + rect.h;

        return self.x > rect_x_lower_bound and
            self.x < rect_x_upper_bound and
            self.y > rect_y_lower_bound and
            self.y < rect_y_upper_bound;
    }
};

pub const Rect = struct {
    x: u32,
    y: u32,
    w: u32,
    h: u32,
};

pub const PrimaryId = []const u8;
pub const SecondaryId = u32;

pub fn idsEqual(a: ?Id, b: ?Id) bool {
    if (a == null or b == null) return false;

    return a.?.isEqual(b.?);
}

pub fn button(ui: *State, id: Id, rect: Rect, text: []const u8) bool {
    var result = false;
    for (ui.renderers) |r| {
        r.button(rect, text);
    }

    if (idsEqual(ui.active, id)) {
        if (ui.mouse.left_up) {
            if (idsEqual(ui.hot, id) and ui.mouse.isInRect(rect)) {
                result = true;
            }
            ui.active = null;
        }
    } else if (idsEqual(ui.hot, id)) {
        if (ui.mouse.left_down and ui.mouse.isInRect(rect)) ui.active = id;
    }

    if (ui.mouse.isInRect(rect)) {
        ui.hot = id;
    }

    return result;
}

pub const nullRenderer = Renderer{ .button = nullButton };

pub fn nullButton(rect: Rect, text: []const u8) void {
    return;
}

test "button is hot when mouse is inside its rect" {
    const renderers = &[_]Renderer{nullRenderer};
    var state = State{
        .renderers = renderers,
        .mouse = Mouse{ .x = 53, .y = 6 },
    };
    const button_id = makeId("testButton", 0);
    var button_clicked = button(
        &state,
        button_id,
        Rect{ .x = 4, .y = 5, .w = 50, .h = 50 },
        "Test",
    );

    testing.expectEqual(button_clicked, false);
    testing.expect(idsEqual(state.hot, button_id));
}
