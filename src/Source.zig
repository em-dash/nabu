const Source = @This();
var norm_data: Normalize.NormData = undefined;
var normalize: Normalize = undefined;

allocator: std.mem.Allocator,
filename: []u8,
// requires a managed array list for `readAllArrayList`
raw: std.ArrayList(u8),
normalized: []u8,
/// Indicies of the start of each line in `normalized`.
line_starts: ?[]u32,

pub inline fn getLineSlice(self: Source, line: u32) []u8 {
    if (line < self.line_starts.len - 1)
        return self.normalized[self.line_starts[line]..self.line_starts[line + 1]];
    return self.normalized[self.line_starts[line]..];
}

pub fn getLocation(self: *Source, target_index: u32) !Location {
    try self.calculateIndicies();

    for (self.line_starts, 0..) |index, l| {
        // if (index > target_index) return self.normalized[index - 1 .. index];
        // TODO calculate column with zg
        if (index > target_index) return .{ .line = l - 1, .column = 0 };
    }

    unreachable;
}

fn calculateIndicies(self: *Source) !void {
    if (self.line_starts != null) return;

    var list: std.ArrayListUnmanaged(u32) = .{};
    var iterator = code_point.Iterator{ .bytes = self.normalized };

    while (iterator.next()) |cp| {
        if (cp.code == '\n') try list.append(self.allocator, cp.offset + 1);
    }

    // If the last codepoint was '\n', then we have added an invalid line start to our list.
    // Remove it.
    if (list.items[list.items.len - 1] >= self.normalized.len)
        _ = list.items.pop();
}

pub fn create(allocator: std.mem.Allocator, filename: []const u8) !*Source {
    const result = try allocator.create(Source);
    result.* = .{
        .allocator = allocator,
        .filename = try allocator.dupe(u8, filename),
        .raw = std.ArrayList(u8).init(allocator),
        .normalized = &[_]u8{},
        .line_starts = null,
    };
    return result;
}

pub fn destroy(self: *Source) void {
    const allocator = self.allocator;
    if (self.line_starts) |slice| {
        allocator.free(slice);
    }
    allocator.free(self.normalized);
    allocator.destroy(self);
}

pub fn readAndNormalize(self: *Source) !void {
    std.log.debug("reading from {s}...", .{self.filename});
    const file = try std.fs.cwd().createFile(self.filename, .{ .read = true });
    defer file.close();

    try file.reader().readAllArrayList(&self.raw, std.math.maxInt(usize));
    defer self.raw.clearAndFree();

    std.log.debug("normalizing...", .{});
    // It seems a bit weird to dupe here but it's safer.  Could be fixed in the future; if you
    // change this, be careful with zg's allocations.
    const temp = try normalize.nfc(self.allocator, self.raw.items);
    defer temp.deinit();
    self.normalized = try self.allocator.dupe(u8, temp.slice);
}

pub fn initNormalization(allocator: std.mem.Allocator) !void {
    std.log.debug("initializing normalization...", .{});
    try Normalize.NormData.init(&norm_data, allocator);
    Source.normalize = Normalize{ .norm_data = &norm_data };
}

pub fn deinitNormalization() void {
    std.log.debug("deinitializing normalization...", .{});
    norm_data.deinit();
}

const Location = struct {
    line: u32,
    column: u32,
};

const std = @import("std");
const Normalize = @import("Normalize");
const code_point = @import("code_point");
