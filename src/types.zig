const std = @import("std");
const assert = std.debug.assert;
const Value = std.atomic.Value;
const AutoHashMap = std.AutoHashMap;

const Function = struct {};

const Type = enum(u16) {
    int,
    float,
    bool,
    _,
};

const SmallType = enum(u2) {
    int,
    float,
    bool,
    reference,
};

const Error = enum(u16) {
    ok,
    _,
};

const ObjectData = struct {
    // refs: usize,
    type: Type, // this is duplicated from the small object which is a little awkward idk
};

const String = struct {
    header: ObjectData,
    slice: []u8,
};

const Object = packed struct {
    comptime {
        assert(@bitSizeOf(Object) == 64);
    }

    data: union { // 32
        id: u32,
        small_int: i32,
        small_float: f32,
        bool: bool,
    },
    type: Type, // 48
    optional: bool, // 49
    is_null: bool, // 50
    @"error": Error, // 64
};
