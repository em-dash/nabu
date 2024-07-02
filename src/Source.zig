const Source = @This();
var norm_data: ?Normalize.NormData = null;
var normalize: ?Normalize = null;

filename: []u8,
abnormal: std.ArrayList(u8),
normal: []u8,
line_starts: std.ArrayListUnmanaged(u32),

pub fn create(allocator: std.mem.Allocator, filename: []const u8) !*Source {
    const result = try allocator.create(Source);
    result.filename = try allocator.dupe(filename);
    result.abnormal = std.ArrayList(u8).init(allocator);
    result.normal = .{};
    result.line_starts = .{};
    return result;
}

pub fn readAndNormalize(self: Source, allocator: std.mem.Allocator) !void {
    const file = try std.fs.cwd().createFile(self.filename, .{ .read = true });
    defer file.close();

    try file.readAllArrayList(&self.abnormal, std.math.maxInt(usize));
    defer self.abnormal.clearAndFree();

    self.normal = (try normalize.nfc(allocator, self.abnormal.items)).slice;
}

pub fn initNormalization(allocator: std.mem.Allocator) !void {
    try Normalize.NormData.init(&norm_data, allocator);
    Source.normalizer = Normalize{ .norm_data = &norm_data };
}

pub fn deinitNormalization() void {
    norm_data.deinit();
}

const std = @import("std");
const Normalize = @import("Normalize");
