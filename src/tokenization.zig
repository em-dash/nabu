const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const unicode = std.unicode;
const ziglyph = @import("ziglyph");

const ArrayList = std.ArrayList;

pub const Token = struct {
    tag: Tag,
    // `source[start..end]` gets a slice containing the text corresponding to just this token
    start: usize,
    end: usize,

    pub const Tag = enum {
        invalid,
        identifier,
        string_literal,
        integer_literal,
        l_paren,
        r_paren,
        semicolon,
        l_brace,
        r_brace,
        comma,
        plus,
        minus,
        forward_slash,
        asterisk,
        single_equals,
        double_equals,
        keyword_if,
        keyword_while,
        keyword_const,
        keyword_var,
        keyword_fn,
        colon,
        dot,
    };
};

pub const Tokenizer = struct {
    buffer: []const u8,
    iterator: unicode.Utf8Iterator,
    allocator: mem.Allocator,

    const keywords = k: {
        // This is a little silly but why not
        const Tuple = std.meta.Tuple(&[_]type{ []const u8, Token.Tag });
        var index = 0;
        // On account of this being silly, it seems like it's hard to make a growable array of
        // this type
        var list: [100]Tuple = undefined;
        for (std.enums.values(Token.Tag)) |v| {
            const t = @tagName(v);
            if (std.mem.startsWith(u8, t, "keyword_")) {
                list[index] = .{ t[8..], v };
                index += 1;
            }
        }
        break :k std.ComptimeStringMap(Token.Tag, list[0..index]);
    };

    const State = enum {
        start,
        forward_slash,
        comment,
        word,
        string_literal,
        integer_literal,
        zero,
        equals,
    };

    pub fn init(allocator: mem.Allocator, source: []const u8) !Tokenizer {
        return .{
            .allocator = allocator,
            .buffer = source,
            .iterator = (try unicode.Utf8View.init(source)).iterator(),
        };
    }

    /// Caller owns returned memory.
    pub fn tokenize(self: *Tokenizer) ![]Token {
        var list = ArrayList(Token).init(self.allocator);
        while (self.next()) |token| try list.append(token);
        return list.toOwnedSlice();
    }

    fn next(self: *Tokenizer) ?Token {
        var state = State.start;
        var result = Token{
            .tag = undefined,
            .start = self.iterator.i,
            .end = undefined,
        };

        loop: while (true) {
            // Store the current iterator position, so we can fix the state after overshooting a
            // variable-length token.
            const prev_index = self.iterator.i;
            const maybe_cp = self.iterator.nextCodepoint();

            switch (state) {
                .start => if (maybe_cp) |cp| switch (cp) {
                    ' ', '\t', '\n', '\r' => {
                        result.start = self.iterator.i;
                    },
                    'a'...'z', 'A'...'Z', '_' => state = .word,
                    '1'...'9' => state = .integer_literal,
                    '0' => state = .zero,
                    '(' => {
                        result.tag = .l_paren;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                    ')' => {
                        result.tag = .r_paren;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                    '{' => {
                        result.tag = .l_brace;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                    '}' => {
                        result.tag = .r_brace;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                    ';' => {
                        result.tag = .semicolon;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                    ':' => {
                        result.tag = .colon;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                    '"' => state = .string_literal,
                    '/' => state = .forward_slash,
                    '+' => {
                        result.tag = .plus;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                    '-' => {
                        result.tag = .minus;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                    '*' => {
                        result.tag = .asterisk;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                    ',' => {
                        result.tag = .comma;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                    '=' => state = .equals,
                    '.' => {
                        result.tag = .dot;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                    else => {
                        // const buf: [4]u8 = undefined;
                        // const len = try std.unicode.utf8Encode(cp, buf);
                        std.debug.panic(
                            "not implemented, currently at codepoint {d}: {u}",
                            .{ self.iterator.i, cp },
                        );
                    },
                } else return null,
                .equals => if (maybe_cp) |cp| switch (cp) {
                    '=' => {
                        result.tag = .double_equals;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                    else => {
                        self.iterator.i = prev_index;
                        result.tag = .single_equals;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                } else {
                    result.tag = .single_equals;
                    result.end = self.iterator.i;
                    break :loop;
                },
                .zero => if (maybe_cp) |cp| switch (cp) {
                    '0'...'9', 'x', 'o', 'b' => state = .integer_literal,
                    else => {
                        self.iterator.i = prev_index;
                        result.tag = .integer_literal;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                } else {
                    result.tag = .integer_literal;
                    result.end = self.iterator.i;
                    break :loop;
                },
                .forward_slash => if (maybe_cp) |cp| switch (cp) {
                    '/' => state = .comment,
                    else => {
                        self.iterator.i = prev_index;
                        result.tag = .identifier;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                } else {
                    self.iterator.i = prev_index;
                    result.tag = .identifier;
                    result.end = self.iterator.i;
                    break :loop;
                },
                .comment => if (maybe_cp) |cp| switch (cp) {
                    '\n' => {
                        state = .start;
                        result.start = self.iterator.i;
                    },
                    else => {},
                } else return null,
                .string_literal => if (maybe_cp) |cp| switch (cp) {
                    '"' => {
                        result.tag = .string_literal;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                    else => {},
                },
                .word => if (maybe_cp) |cp| switch (cp) {
                    'a'...'z', 'A'...'Z', '_' => {},
                    else => {
                        self.iterator.i = prev_index;
                        result.end = self.iterator.i;
                        result.tag = keywords.get(self.buffer[result.start..result.end]) orelse
                            .identifier;
                        break :loop;
                    },
                } else {
                    self.iterator.i = prev_index;
                    result.tag = .identifier;
                    result.end = self.iterator.i;
                    break :loop;
                },
                .integer_literal => if (maybe_cp) |cp| switch (cp) {
                    '0'...'9', 'a'...'f', 'A'...'F', '_' => {},
                    else => {
                        self.iterator.i = prev_index;
                        result.tag = .integer_literal;
                        result.end = self.iterator.i;
                        break :loop;
                    },
                } else {
                    self.iterator.i = prev_index;
                    result.tag = .integer_literal;
                    result.end = self.iterator.i;
                    break :loop;
                },
            }
        }

        return result;
    }
};

test "assignment" {
    const source =
        \\cats = 100;
    ;
    const expected = [_]Token{
        .{ .tag = .identifier, .start = 0, .end = 4 },
        .{ .tag = .single_equals, .start = 5, .end = 6 },
        .{ .tag = .integer_literal, .start = 7, .end = 10 },
        .{ .tag = .semicolon, .start = 10, .end = 11 },
    };
    try expectTokens(&expected, source);
}

test "dot operator assignment" {
    const source =
        \\cats.cuteness = 9001;
    ;
    const expected = [_]Token{
        .{ .tag = .identifier, .start = 0, .end = 4 },
        .{ .tag = .dot, .start = 4, .end = 5 },
        .{ .tag = .identifier, .start = 5, .end = 13 },
        .{ .tag = .single_equals, .start = 14, .end = 15 },
        .{ .tag = .integer_literal, .start = 16, .end = 20 },
        .{ .tag = .semicolon, .start = 20, .end = 21 },
    };
    try expectTokens(&expected, source);
}

test "equality" {
    const source =
        \\dogs == 100
    ;
    const expected = [_]Token{
        .{ .tag = .identifier, .start = 0, .end = 4 },
        .{ .tag = .double_equals, .start = 5, .end = 7 },
        .{ .tag = .integer_literal, .start = 8, .end = 11 },
    };
    try expectTokens(&expected, source);
}

test "hello world" {
    const source =
        \\print("hello worl");
        \\// comment
    ;
    const expected = [_]Token{
        .{ .tag = .identifier, .start = 0, .end = 5 },
        .{ .tag = .l_paren, .start = 5, .end = 6 },
        .{ .tag = .string_literal, .start = 6, .end = 18 },
        .{ .tag = .r_paren, .start = 18, .end = 19 },
        .{ .tag = .semicolon, .start = 19, .end = 20 },
    };
    try expectTokens(&expected, source);
}

test "add two ints" {
    const source =
        \\420 + 69
    ;
    const expected = [_]Token{
        .{ .tag = .integer_literal, .start = 0, .end = 3 },
        .{ .tag = .plus, .start = 4, .end = 5 },
        .{ .tag = .integer_literal, .start = 6, .end = 8 },
    };
    try expectTokens(&expected, source);
}

test "decimal integer literal" {
    const source =
        \\5_318_008
    ;
    const expected = [_]Token{
        .{ .tag = .integer_literal, .start = 0, .end = 9 },
    };
    try expectTokens(&expected, source);
}

test "hexadecimal integer literal" {
    const source =
        \\0xCAfE_BeeF
    ;
    const expected = [_]Token{
        .{ .tag = .integer_literal, .start = 0, .end = 11 },
    };
    try expectTokens(&expected, source);
}

test "binary integer literal" {
    const source =
        \\0b010000_10___101001010101
    ;
    const expected = [_]Token{
        .{ .tag = .integer_literal, .start = 0, .end = 26 },
    };
    try expectTokens(&expected, source);
}

test "keywords" {
    const source =
        \\if while const var beepboop
    ;
    const expected = [_]Token{
        .{ .tag = .keyword_if, .start = 0, .end = 2 },
        .{ .tag = .keyword_while, .start = 3, .end = 8 },
        .{ .tag = .keyword_const, .start = 9, .end = 14 },
        .{ .tag = .keyword_var, .start = 15, .end = 18 },
        .{ .tag = .identifier, .start = 19, .end = 27 },
    };
    try expectTokens(&expected, source);
}

test "negative integer literal" {
    const source =
        \\-2_323
    ;
    const expected = [_]Token{
        .{ .tag = .minus, .start = 0, .end = 1 },
        .{ .tag = .integer_literal, .start = 1, .end = 6 },
    };
    try expectTokens(&expected, source);
}

fn expectTokens(expected: []const Token, source: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var tokenizer = try Tokenizer.init(allocator, source);
    const tokens = try tokenizer.tokenize();
    try testing.expectEqualSlices(Token, expected[0..], tokens);
}
