const std = @import("std");
const Value = std.atomic.Value;

const ObjectHeader = struct {
    refs: usize,
};

const String = struct {
    header: ObjectHeader,
    slice: []u8,
};

const Object = union(enum) {
    small_int: i32,
    // small_float: f32,
    bool: bool,
    heap_object: *ObjectHeader,
};
