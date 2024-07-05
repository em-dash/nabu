var props_data: PropsData = undefined;

pub fn initPropsData(allocator: std.mem.Allocator) !void {
    std.log.debug("initializing property data...", .{});
    props_data = try PropsData.init(allocator);
}

pub fn deinitPropsData() void {
    std.log.debug("deinitializing property data...", .{});
    props_data.deinit();
}

pub fn tokenizeSource(allocator: std.mem.Allocator, source: *Source) ![]const Token {
    std.log.debug("tokenizing...", .{});

    var list: std.ArrayListUnmanaged(Token) = .{};
    var iterator = code_point.Iterator{ .bytes = source.normalized };

    loop: while (true) {
        var token: Token = undefined;
        token.start = iterator.i;
        var state = State.start;

        token_loop: while (true) {
            const maybe_cp = iterator.peek();
            switch (state) {
                .start => {
                    const cp = maybe_cp orelse break :loop;
                    if (cp.code == '&')
                        state = .ampersand
                    else if (cp.code == '*')
                        state = .asterisk
                    else if (cp.code == '^')
                        state = .caret
                    else if (cp.code == '.')
                        state = .dot
                    else if (cp.code == '=')
                        state = .equals
                    else if (cp.code == '!')
                        state = .exclam
                    else if (cp.code == '/')
                        state = .forwardslash
                    else if (cp.code == '>')
                        state = .greater
                    else if (cp.code == '<')
                        state = .less
                    else if (cp.code == '-')
                        state = .minus
                    else if (cp.code == '%')
                        state = .percent
                    else if (cp.code == '|')
                        state = .pipe
                    else if (cp.code == '+')
                        state = .plus
                    else if (props_data.isXidStart(cp.code))
                        state = .word
                    else if (props_data.isWhitespace(cp.code)) {
                        _ = iterator.next();
                        token.start = iterator.i;
                    } else if (cp.code == '"')
                        state = .string_literal
                    else {
                        if (cp.code == ':') {
                            token.tag = .colon;
                        } else if (cp.code == ',') {
                            token.tag = .colon;
                        } else if (cp.code == '{') {
                            token.tag = .l_brace;
                        } else if (cp.code == '[') {
                            token.tag = .l_bracket;
                        } else if (cp.code == '(') {
                            token.tag = .l_paren;
                        } else if (cp.code == '}') {
                            token.tag = .r_brace;
                        } else if (cp.code == ']') {
                            token.tag = .r_bracket;
                        } else if (cp.code == ')') {
                            token.tag = .r_paren;
                        } else {
                            try errors.print(.{ .invalid_character = iterator.i }, source);
                            return error.InvalidCharacter;
                        }
                        _ = iterator.next();
                        token.end = iterator.i;
                        break :token_loop;
                    }
                },
                .ampersand => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .asterisk => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .asterisk_percent => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .asterisk_pipe => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .caret => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .dot => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .dot_dot => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .equals => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .exclam => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .forwardslash => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .greater => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .greater_greater => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .less => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .less_less => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .less_less_pipe => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .minus => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .minus_percent => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .minus_pipe => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .percent => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .pipe => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .plus => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .plus_percent => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .plus_pipe => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .word => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
                .string_literal => {
                    const cp = maybe_cp orelse break :loop;
                    _ = cp;
                },
            }
        }
        try list.append(allocator, token);
    }

    return try list.toOwnedSlice(allocator);
}

const Token = struct {
    // Such that `Source.normal[start..end]` gets a slice of this token.
    start: u32,
    end: u32,
    tag: Tag,
};

const Tag = enum {
    ampersand_equals,
    ampersand,
    asterisk_asterisk,
    asterisk_equals,
    asterisk_percent_equals,
    asterisk_percent,
    asterisk_pipe_equals,
    asterisk_pipe,
    asterisk,
    caret_equals,
    caret,
    colon,
    comma,
    dot_asterisk,
    dot_dot_dot,
    dot_dot,
    dot_questionmark,
    dot,
    equals_equals,
    equals_greater,
    equals,
    exclam_equals,
    exclam,
    forwardslash_equals,
    forwardslash,
    greater_equals,
    greater_greater_equals,
    greater_greater,
    greater,
    l_brace,
    l_bracket,
    less_equals,
    less_less_equals,
    less_less_pipe_equals,
    less_less_pipe,
    less_less,
    less,
    l_paren,
    minus_equals,
    minus_percent_equals,
    minus_pipe_equals,
    minus,
    octothorpe,
    percent_equals,
    percent,
    pipe_equals,
    pipe,
    plus_equals,
    plus_percent_equals,
    plus_percent,
    plus_pipe_equals,
    plus_pipe,
    plus_plus,
    plus,
    r_brace,
    r_bracket,
    r_paren,
    semicolon,
};

const State = enum {
    start,
    ampersand,
    asterisk,
    asterisk_percent,
    asterisk_pipe,
    caret,
    dot,
    dot_dot,
    equals,
    exclam,
    forwardslash,
    greater,
    greater_greater,
    less,
    less_less,
    less_less_pipe,
    minus,
    minus_percent,
    minus_pipe,
    percent,
    pipe,
    plus,
    plus_percent,
    plus_pipe,
    word,
    string_literal,
};

const std = @import("std");
const code_point = @import("code_point");
const PropsData = @import("PropsData");

const Source = @import("Source.zig");
const errors = @import("errors.zig");
