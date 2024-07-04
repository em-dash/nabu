const Source = @This();
var norm_data: Normalize.NormData = undefined;
var normalize: Normalize = undefined;

allocator: std.mem.Allocator,
filename: []u8,
// requires a managed array list for `readAllArrayList`
raw: std.ArrayList(u8),
normalized: []u8,
/// Indicies of the start of each line in `normalized`.
line_starts: ?[]u32 = null,

pub fn calculateIndicies(self: *Source) !void {
    var list: std.ArrayListUnmanaged(u32) = .{};
    var iterator = code_point.Iterator{ .bytes = self.normalized };

    while (iterator.next()) |cp| {
        if (cp.code == \n)
    }
}

pub fn create(allocator: std.mem.Allocator, filename: []const u8) !*Source {
    const result = try allocator.create(Source);
    result.* = .{
        .allocator = allocator,
        .filename = try allocator.dupe(u8, filename),
        .raw = std.ArrayList(u8).init(allocator),
        .normalized = &[_]u8{},
        .line_starts = .{},
    };
    return result;
}

pub fn destroy(self: *Source) void {
    
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

const std = @import("std");
const Normalize = @import("Normalize");
const code_point = @import("code_point");
