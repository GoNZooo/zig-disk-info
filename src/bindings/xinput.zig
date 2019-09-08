const windows = @import("std").os.windows;

pub const XINPUT_GAMEPAD = extern struct {
    buttons: windows.WORD = 0,
    left_trigger: windows.BYTE = 0,
    right_trigger: windows.BYTE = 0,
    thumb_LX: windows.SHORT = 0,
    thumb_LY: windows.SHORT = 0,
    thumb_RX: windows.SHORT = 0,
    thumb_RY: windows.SHORT = 0,
};

pub const XINPUT_STATE = extern struct {
    packet_number: windows.DWORD = 0,
    gamepad: XINPUT_GAMEPAD = XINPUT_GAMEPAD{},
};
