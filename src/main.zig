const CliArgs = struct {
    filename: []const u8 = &[_]u8{},
    tokenize_only: bool = false,
    parse_only: bool = false,
};

fn processArgs(allocator: std.mem.Allocator) !CliArgs {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next(); // Discard executable path
    var seen_filename = false;
    var result: CliArgs = .{};
    while (args.next()) |arg| {
        if (arg[0] == '-') {
            if (arg[1] == '-') { // Long arguments
                if (std.mem.eql(u8, arg[2..], "tokenize-only"))
                    result.tokenize_only = true
                else if (std.mem.eql(u8, arg[2..], "parse-only"))
                    result.parse_only = true;
            } else { // Short arguments

            }
        } else { // This should be the filename.
            if (seen_filename) {
                std.log.err("Invalid argument: {s}", .{arg});
                return error.InvalidArgument;
            }

            result.filename = try allocator.dupe(u8, arg);
            errdefer allocator.free(result.filename);
            seen_filename = true;
        }
    }

    return result;
}

fn compileAndRun(allocator: std.mem.Allocator, options: helpers.CompileOptions) !void {
    // Load the file.
    try Source.initNormalization(allocator);
    defer Source.deinitNormalization();

    var source = try Source.create(allocator, options.filename);
    defer source.destroy();
    try source.readAndNormalize();

    // Tokenization
    try tokenization.initPropsData(allocator);
    defer tokenization.deinitPropsData();
    const tokens = try tokenization.tokenizeSource(allocator, source);
    _ = tokens;

    if (options.target_stage == .tokenization) return;
    // Parsing
    if (true) std.debug.panic("not implemented", .{});
    if (options.target_stage == .ast) return;
    // AST check
    if (true) std.debug.panic("not implemented", .{});
    if (options.target_stage == .ast_check) return;
    if (true) std.debug.panic("not implemented", .{});
    if (options.target_stage == .cfir) return;
    if (true) std.debug.panic("not implemented", .{});
    if (options.target_stage == .oir) return;
    if (true) std.debug.panic("not implemented", .{});
    if (options.target_stage == .code_gen) return;
    if (true) std.debug.panic("not implemented", .{});
}

const ExitCode = enum(u8) {
    ok = 0,
    no_input_file = 10,

    inline fn int(self: ExitCode) u8 {
        return @intFromEnum(self);
    }
};

pub fn main() !u8 {
    std.log.debug("version: TODO get the version from the build system somehow", .{});
    std.log.debug("zig version: {s}", .{builtin.zig_version_string});

    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    const args = try processArgs(gpa);
    defer gpa.free(args.filename);

    if (args.filename.len == 0) {
        return ExitCode.no_input_file.int();
    }

    const compile_options = blk: {
        var result: helpers.CompileOptions = .{};
        result.filename = args.filename;
        if (args.tokenize_only) result.target_stage = .tokenization;
        if (args.parse_only) result.target_stage = .ast;

        break :blk result;
    };
    try compileAndRun(gpa, compile_options);

    return ExitCode.ok.int();
}

const std = @import("std");
const builtin = @import("builtin");

const helpers = @import("helpers.zig");
const Source = @import("Source.zig");
const tokenization = @import("tokenization.zig");
