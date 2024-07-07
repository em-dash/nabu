var props_data: PropsData = undefined;

pub fn initPropsData(allocator: std.mem.Allocator) !void {
    std.log.debug("initializing property data...", .{});
    props_data = try PropsData.init(allocator);
}

pub fn deinitPropsData() void {
    std.log.debug("deinitializing property data...", .{});
    props_data.deinit();
}

// This should tokenize anything as long as it's a set of valid tokens; ungrammatical code
// should fail at the parsing stage, not here.
pub fn tokenizeSource(
    allocator: std.mem.Allocator,
    source: *Source,
    debug_info: bool,
) ![]const Token {
    std.log.debug("tokenizing...", .{});

    var list: std.ArrayListUnmanaged(Token) = .{};
    var iterator = code_point.Iterator{ .bytes = source.normalized };

    loop: while (true) {
        var token: Token = undefined;
        token.start = iterator.i;
        var state = State.start;

        token_loop: while (true) {
            switch (state) {
                .start => {
                    const cp = iterator.peek() orelse break :loop;
                    if (cp.code == '&') {
                        _ = iterator.next();
                        state = .ampersand;
                        continue :token_loop;
                    } else if (cp.code == '*') {
                        _ = iterator.next();
                        state = .asterisk;
                        continue :token_loop;
                    } else if (cp.code == '^') {
                        _ = iterator.next();
                        state = .caret;
                        continue :token_loop;
                    } else if (cp.code == '.') {
                        _ = iterator.next();
                        state = .dot;
                        continue :token_loop;
                    } else if (cp.code == '\\') {
                        _ = iterator.next();
                        state = .backslash;
                        continue :token_loop;
                    } else if (cp.code == '=') {
                        _ = iterator.next();
                        state = .equals;
                        continue :token_loop;
                    } else if (cp.code == '!') {
                        _ = iterator.next();
                        state = .exclam;
                        continue :token_loop;
                    } else if (cp.code == '/') {
                        _ = iterator.next();
                        state = .forwardslash;
                        continue :token_loop;
                    } else if (cp.code == '>') {
                        _ = iterator.next();
                        state = .greater;
                        continue :token_loop;
                    } else if (cp.code == '<') {
                        _ = iterator.next();
                        state = .less;
                        continue :token_loop;
                    } else if (cp.code == '-') {
                        _ = iterator.next();
                        state = .minus;
                        continue :token_loop;
                    } else if (cp.code == '%') {
                        _ = iterator.next();
                        state = .percent;
                        continue :token_loop;
                    } else if (cp.code == '|') {
                        _ = iterator.next();
                        state = .pipe;
                        continue :token_loop;
                    } else if (cp.code == '+') {
                        _ = iterator.next();
                        state = .plus;
                        continue :token_loop;
                    } else if (props_data.isXidStart(cp.code)) {
                        _ = iterator.next();
                        state = .word;
                        continue :token_loop;
                    } else if (props_data.isWhitespace(cp.code)) {
                        _ = iterator.next();
                        token.start = iterator.i;
                    } else if (cp.code >= '1' and cp.code <= '9') {
                        _ = iterator.next();
                        state = .number;
                        continue :token_loop;
                    } else if (cp.code == '0') {
                        _ = iterator.next();
                        state = .zero;
                        continue :token_loop;
                    } else if (cp.code == '"') {
                        _ = iterator.next();
                        state = .string_literal;
                        continue :token_loop;
                    } else if (cp.code == '`') {
                        _ = iterator.next();
                        state = .universal_identifier;
                        continue :token_loop;
                    } else if (cp.code == ':') {
                        _ = iterator.next();
                        token.tag = .colon;
                        token.end = iterator.i;
                        break :token_loop;
                    } else if (cp.code == ',') {
                        _ = iterator.next();
                        token.tag = .colon;
                        token.end = iterator.i;
                        break :token_loop;
                    } else if (cp.code == '{') {
                        _ = iterator.next();
                        token.tag = .l_brace;
                        token.end = iterator.i;
                        break :token_loop;
                    } else if (cp.code == '[') {
                        _ = iterator.next();
                        token.tag = .l_bracket;
                        token.end = iterator.i;
                        break :token_loop;
                    } else if (cp.code == '(') {
                        _ = iterator.next();
                        token.tag = .l_paren;
                        token.end = iterator.i;
                        break :token_loop;
                    } else if (cp.code == '}') {
                        _ = iterator.next();
                        token.tag = .r_brace;
                        token.end = iterator.i;
                        break :token_loop;
                    } else if (cp.code == ']') {
                        _ = iterator.next();
                        token.tag = .r_bracket;
                        token.end = iterator.i;
                        break :token_loop;
                    } else if (cp.code == ')') {
                        _ = iterator.next();
                        token.tag = .r_paren;
                        token.end = iterator.i;
                        break :token_loop;
                    } else if (cp.code == ';') {
                        _ = iterator.next();
                        token.tag = .r_paren;
                        token.end = iterator.i;
                        break :token_loop;
                    } else {
                        try errors.print(.{ .invalid_character = cp.offset }, source);
                        return error.InvalidCharacter;
                    }
                },
                .ampersand => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .ampersand_equals;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .ampersand;
                    break :token_loop;
                },
                .asterisk => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '%') {
                            _ = iterator.next();
                            state = .asterisk_percent;
                            continue :token_loop;
                        } else if (cp.code == '|') {
                            _ = iterator.next();
                            state = .asterisk_pipe;
                            continue :token_loop;
                        } else if (cp.code == '*') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .asterisk_asterisk;
                            break :token_loop;
                        } else if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .asterisk_equals;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .asterisk;
                    break :token_loop;
                },
                .asterisk_percent => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .asterisk_percent_equals;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .asterisk_percent;
                    break :token_loop;
                },
                .asterisk_pipe => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .asterisk_pipe_equals;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .asterisk_pipe;
                    break :token_loop;
                },
                .caret => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .caret_equals;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .caret;
                    break :token_loop;
                },
                .dot => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '?') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .dot_questionmark;
                            break :token_loop;
                        } else if (cp.code == '*') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .dot_asterisk;
                            break :token_loop;
                        } else if (cp.code == '.') {
                            _ = iterator.next();
                            state = .dot_dot;
                            continue :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .dot;
                    break :token_loop;
                },
                .dot_dot => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '.') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .dot_dot_dot;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .dot_dot;
                    break :token_loop;
                },
                .equals => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .equals_equals;
                            break :token_loop;
                        } else if (cp.code == '>') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .equals_greater;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .equals;
                    break :token_loop;
                },
                .exclam => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .exclam_equals;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .exclam;
                    break :token_loop;
                },
                .forwardslash => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .forwardslash_equals;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .forwardslash;
                    break :token_loop;
                },
                .greater => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .greater_equals;
                            break :token_loop;
                        } else if (cp.code == '>') {
                            _ = iterator.next();
                            state = .greater_greater;
                            continue :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .greater;
                    break :token_loop;
                },
                .greater_greater => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .greater_greater_equals;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .greater_greater;
                    break :token_loop;
                },
                .less => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .less_equals;
                            break :token_loop;
                        } else if (cp.code == '<') {
                            _ = iterator.next();
                            state = .less_less;
                            continue :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .less;
                    break :token_loop;
                },
                .less_less => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .less_less_equals;
                            break :token_loop;
                        } else if (cp.code == '|') {
                            _ = iterator.next();
                            state = .less_less_pipe;
                            continue :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .less_less;
                    break :token_loop;
                },
                .less_less_pipe => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .less_less_pipe_equals;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .less_less_pipe;
                    break :token_loop;
                },
                .minus => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .minus_equals;
                            break :token_loop;
                        } else if (cp.code == '%') {
                            _ = iterator.next();
                            state = .minus_percent;
                            continue :token_loop;
                        } else if (cp.code == '|') {
                            _ = iterator.next();
                            state = .minus_pipe;
                            continue :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .minus;
                    break :token_loop;
                },
                .minus_percent => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .minus_percent_equals;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .minus_percent;
                    break :token_loop;
                },
                .minus_pipe => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .minus_pipe_equals;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .minus_pipe;
                    break :token_loop;
                },
                .percent => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .percent_equals;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .percent;
                    break :token_loop;
                },
                .pipe => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .pipe_equals;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .pipe;
                    break :token_loop;
                },
                .plus => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .plus_equals;
                            break :token_loop;
                        } else if (cp.code == '%') {
                            _ = iterator.next();
                            state = .plus_percent;
                            continue :token_loop;
                        } else if (cp.code == '|') {
                            _ = iterator.next();
                            state = .plus_pipe;
                            continue :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .plus;
                    break :token_loop;
                },
                .plus_percent => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .plus_percent_equals;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .plus_percent;
                    break :token_loop;
                },
                .plus_pipe => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '=') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .plus_pipe_equals;
                            break :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .plus_pipe;
                    break :token_loop;
                },
                .word => {
                    if (iterator.peek()) |cp| {
                        if (props_data.isXidContinue(cp.code)) {
                            _ = iterator.next();
                            continue :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = keywords.get(source.normalized[token.start..token.end]) orelse
                        .identifier;
                    break :token_loop;
                },
                .string_literal => {
                    //
                    if (iterator.peek()) |cp| {
                        if (cp.code == '"') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .string_literal;
                            break :token_loop;
                        } else if (cp.code == '\\') {
                            _ = iterator.next();
                            state = .string_literal_backslash;
                            continue :token_loop;
                        } else {
                            _ = iterator.next();
                            continue :token_loop;
                        }
                    }
                    try errors.print(.{ .mismatched_quotes = iterator.i }, source);
                    return error.MismatchedQuotes;
                },
                .string_literal_backslash => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '\n') {
                            try errors.print(.{ .mismatched_quotes = iterator.i }, source);
                            return error.MismatchedQuotes;
                        }
                        _ = iterator.next();
                        state = .string_literal;
                        continue :token_loop;
                    }
                    try errors.print(.{ .mismatched_quotes = iterator.i }, source);
                    return error.MismatchedQuotes;
                },
                .universal_identifier => {
                    //
                    if (iterator.peek()) |cp| {
                        if (cp.code == '`') {
                            _ = iterator.next();
                            token.end = iterator.i;
                            token.tag = .identifier;
                            break :token_loop;
                        } else if (cp.code == '\\') {
                            _ = iterator.next();
                            state = .universal_identifier_backslash;
                            continue :token_loop;
                        } else {
                            _ = iterator.next();
                            continue :token_loop;
                        }
                    }
                    try errors.print(.{ .mismatched_backticks = iterator.i }, source);
                    return error.MismatchedBackticks;
                },
                .universal_identifier_backslash => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '\n') {
                            try errors.print(.{ .mismatched_backticks = iterator.i }, source);
                            return error.MismatchedBackticks;
                        }
                        _ = iterator.next();
                        state = .universal_identifier;
                        continue :token_loop;
                    }
                    try errors.print(.{ .mismatched_backticks = iterator.i }, source);
                    return error.MismatchedBackticks;
                },
                .zero => {
                    if (iterator.peek()) |cp| {
                        if ((cp.code >= '0' and cp.code <= '9') or cp.code == '_') {
                            _ = iterator.next();
                            state = .number;
                            continue :token_loop;
                        } else if (cp.code == 'x') {
                            _ = iterator.next();
                            state = .hex;
                            continue :token_loop;
                        } else if (cp.code == 'b') {
                            _ = iterator.next();
                            state = .number;
                            continue :token_loop;
                        } else if (cp.code == 'o') {
                            _ = iterator.next();
                            state = .number;
                            continue :token_loop;
                        }
                    }
                },
                .number => {
                    if (iterator.peek()) |cp| {
                        if ((cp.code >= '0' and cp.code <= '9') or cp.code == '_') {
                            _ = iterator.next();
                            continue :token_loop;
                        } else if (cp.code == '.') {
                            _ = iterator.next();
                            state = .number_float;
                            continue :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .integer;
                    break :token_loop;
                },
                .number_float => {
                    if (iterator.peek()) |cp| {
                        if ((cp.code >= '0' and cp.code <= '9') or cp.code == '_') {
                            _ = iterator.next();
                            continue :token_loop;
                        } else if (cp.code == 'E' or cp.code == 'e') {
                            _ = iterator.next();
                            state = .number_float_e;
                            continue :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .integer;
                    break :token_loop;
                },
                .number_float_e => {
                    if (iterator.peek()) |cp| {
                        if ((cp.code >= '0' and cp.code <= '9') or
                            cp.code == '+' or
                            cp.code == '-')
                        {
                            _ = iterator.next();
                            state = .number_float;
                            continue :token_loop;
                        }
                    }
                    try errors.print(.{ .invalid_float_literal = token.start }, source);
                    return error.InvalidFloatLiteral;
                },
                .hex => {
                    if (iterator.peek()) |cp| {
                        if ((cp.code >= '0' and cp.code <= '9') or
                            (cp.code >= 'A' and cp.code <= 'F') or
                            (cp.code >= 'a' and cp.code <= 'f') or
                            cp.code == '_')
                        {
                            _ = iterator.next();
                            continue :token_loop;
                        } else if (cp.code == '.') {
                            _ = iterator.next();
                            state = .hex_float;
                            continue :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .integer;
                    break :token_loop;
                },
                .hex_float => {
                    if (iterator.peek()) |cp| {
                        if ((cp.code >= '0' and cp.code <= '9') or cp.code == '_') {
                            _ = iterator.next();
                            continue :token_loop;
                        } else if (cp.code == 'P' or cp.code == 'p') {
                            _ = iterator.next();
                            state = .hex_float_p;
                            continue :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .integer;
                    break :token_loop;
                },
                .hex_float_p => {
                    if (iterator.peek()) |cp| {
                        if ((cp.code >= '0' and cp.code <= '9') or
                            cp.code == '+' or
                            cp.code == '-')
                        {
                            _ = iterator.next();
                            state = .hex_float;
                            continue :token_loop;
                        }
                    }
                    try errors.print(.{ .invalid_float_literal = token.start }, source);
                    return error.InvalidFloatLiteral;
                },
                .backslash => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '\\') {
                            _ = iterator.next();
                            state = .multiline_string_literal;
                            continue :token_loop;
                        }
                        try errors.print(.{ .invalid_character = cp.offset }, source);
                        return error.UnexpectedCharacter;
                    }
                    try errors.print(.unexpected_eof, source);
                    return error.UnexpectedEof;
                },
                .multiline_string_literal => {
                    if (iterator.peek()) |cp| {
                        if (cp.code == '\n') {
                            _ = iterator.next();
                            state = .multiline_string_literal_newline;
                            continue :token_loop;
                        } else {
                            _ = iterator.next();
                            continue :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .integer;
                    break :token_loop;
                },
                .multiline_string_literal_newline => {
                    if (iterator.peek()) |cp| {
                        if (props_data.isWhitespace(cp.code)) {
                            _ = iterator.next();
                            continue :token_loop;
                        } else if (cp.code == '\\') {
                            _ = iterator.next();
                            state = .backslash;
                            continue :token_loop;
                        }
                    }
                    token.end = iterator.i;
                    token.tag = .integer;
                    break :token_loop;
                },
            }
        }
        if (debug_info) {
            std.log.debug(
                "found token: {s:.>26} {s}",
                .{ @tagName(token.tag), source.normalized[token.start..token.end] },
            );
        }
        try list.append(allocator, token);
    }

    return try list.toOwnedSlice(allocator);
}

const keywords = k: {
    // This is a little silly but why not
    const Tuple = std.meta.Tuple(&[_]type{ []const u8, Tag });
    var list: []const Tuple = &[_]Tuple{};
    for (std.enums.values(Tag)) |v| {
        const t = @tagName(v);
        if (std.mem.startsWith(u8, t, "keyword_")) {
            list = list ++ &[_]Tuple{.{ t[8..], v }};
        }
    }
    break :k std.StaticStringMap(Tag).initComptime(list);
};

const Token = struct {
    // Such that `Source.normalized[start..end]` gets a slice of this token.
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
    string_literal,
    caret_equals,
    caret,
    colon,
    comma,
    dot_asterisk,
    dot_dot_dot,
    dot_dot,
    identifier,
    dot_questionmark,
    dot,
    equals_equals,
    equals_greater,
    equals,
    exclam_equals,
    exclam,
    forwardslash_equals,
    forwardslash,
    float,
    greater_equals,
    greater_greater_equals,
    greater_greater,
    greater,
    integer,
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
    minus_percent,
    minus_pipe_equals,
    minus_pipe,
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
    keyword_module,
    keyword_interface,
    keyword_enum,
    keyword_fn,
    keyword_struct,
    keyword_var,
    keyword_const,
    keyword_if,
    keyword_else,
    keyword_defer,
    keyword_errdefer,
    keyword_error,
    keyword_break,
    keyword_continue,
    keyword_switch,
    keyword_while,
    keyword_for,
    keyword_orelse,
    keyword_catch,
    keyword_or,
    keyword_and,
    keyword_try,
    keyword_return,
    keyword_implements,
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
    string_literal_backslash,
    backslash,
    multiline_string_literal,
    multiline_string_literal_newline,
    zero,
    hex,
    number,
    hex_float,
    number_float,
    hex_float_p,
    number_float_e,
    universal_identifier,
    universal_identifier_backslash,
};

const std = @import("std");
const code_point = @import("code_point");
const PropsData = @import("PropsData");

const Source = @import("Source.zig");
const errors = @import("errors.zig");
