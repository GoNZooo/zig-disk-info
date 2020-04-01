const std = @import("std");
const mem = std.mem;
const testing = std.testing;

pub fn State(comptime suppliedRenderers: []Renderer) type {
    return struct {
        renderers: []const Renderer = suppliedRenderers,
        hot: ?Id = null,
        active: ?Id = null,
    };
}

pub fn makeId(primary: PrimaryId, secondary: SecondaryId) Id {
    return Id{ .primary = primary, .secondary = secondary };
}

const Id = struct {
    primary: PrimaryId,
    secondary: SecondaryId = 0,

    pub fn isEqual(self: Id, id: Id) bool {
        return mem.eql(u8, self.primary, id.primary) and self.secondary == id.secondary;
    }
};

const Renderer = struct {
    button: fn (rect: Rect, text: []const u8) void,
};

const Mouse = struct {
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

const Rect = struct {
    x: u32,
    y: u32,
    w: u32,
    h: u32,
};

const PrimaryId = []const u8;
const SecondaryId = u32;

fn idsEqual(a: ?Id, b: ?Id) bool {
    if (a == null or b == null) return false;

    return a.?.isEqual(b.?);
}

pub fn button(
    comptime renderers: []Renderer,
    ui: *State(renderers),
    id: Id,
    rect: Rect,
    text: []const u8,
    mouse: Mouse,
) bool {
    var result = false;
    for (ui.renderers) |r| {
        r.button(rect, text);
    }

    if (idsEqual(ui.active, id)) {
        if (mouse.left_up) {
            if (idsEqual(ui.hot, id) and mouse.isInRect(rect)) {
                result = true;
            }
            ui.active = null;
        }
    } else if (idsEqual(ui.hot, id)) {
        if (mouse.left_down and mouse.isInRect(rect)) ui.active = id;
    }

    if (mouse.isInRect(rect)) {
        ui.hot = id;
    }

    return result;
}

fn drawNothingButton(rect: Rect, text: []const u8) void {
    return;
}

test "button is hot when inside it" {
    const renderers = &[_]Renderer{.{ .button = drawNothingButton }};
    var state = State(renderers){};
    const button_id = makeId("testButton", 0);
    var button_clicked = button(
        renderers,
        &state,
        button_id,
        Rect{ .x = 0, .y = 0, .w = 50, .h = 50 },
        "Test",
        Mouse{ .x = 49, .y = 1 },
    );

    testing.expectEqual(button_clicked, false);
    testing.expect(idsEqual(state.hot, button_id));
}
