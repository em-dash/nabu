const std = @import("std");
const tokenize = @import("tokenization.zig");
const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const log = std.log;

const Tokenizer = tokenize.Tokenizer;
const Token = tokenize.Token;

const ParseError = error{
    MismatchedBraces,
    MismatchedParentheses,
} || Allocator.Error;

/// Returns the index of the first instance of any `needle` in `haystack`.
fn scanTokensInScope(comptime needle: []const Token.Tag, haystack: []const Token) !?usize {
    var paren_depth: u32 = 0;
    var brace_depth: u32 = 0;
    for (haystack, 0..) |h, i| {
        switch (h.tag) {
            .l_paren => paren_depth += 1,
            .l_brace => brace_depth += 1,
            .r_paren => {
                if (paren_depth == 0) return error.MismatchedParentheses;
                paren_depth -= 1;
            },
            .r_brace => {
                if (brace_depth == 0) return error.MismatchedBraces;
                brace_depth -= 1;
            },
            else => {
                if (paren_depth == 0 and brace_depth == 0) {
                    inline for (needle) |n| {
                        if (h.tag == n) return i;
                    }
                }
            },
        }
    }

    return null;
}

/// Returns the token offset to the matching right parenthesis.
///
/// E.g., for `foo()` returns 1.  For `foo(a, b)` returns 4.
// fn findMatchingParen(tokens: []Token) usize {
//     assert(tokens[0].tag == .l_paren);
//     var depth: usize = 1;
//     for (tokens[1..], 1..) |t, i| {
//         switch (t.tag) {
//             .l_paren => depth += 1,
//             .r_paren => {
//                 if (depth == 1) return i else depth -= 1;
//             },
//             else => {},
//         }
//     }
//     std.debug.panic("mismatched parentheses", .{});
// }

pub const ScopedIdentifier = struct {
    identifiers: []*Token,

    fn parse(allocator: Allocator, tokens: []Token) ParseError!ScopedIdentifier {
        var list = ArrayList(*Token).init(allocator);
        var index: usize = 0;
        while (true) {
            if (tokens[index].tag != .identifier) std.debug.panic("invalid token", .{});
            try list.append(&tokens[index]);
            index += 1;
            if (index >= tokens.len) break;
            if (tokens[index].tag != .dot) std.debug.panic("invalid token", .{});
            index += 1;
            if (index >= tokens.len) std.debug.panic("invalid token", .{});
        }
        return .{ .identifiers = try list.toOwnedSlice() };
    }
};

pub const TypedIdentifier = struct {
    identifier: *Token,
    type: ScopedIdentifier,
};

pub const BinaryOperation = struct {
    lhs: *Expression,
    operator: *Token,
    rhs: *Expression,
};

/// `operand` must be an expression that evaluates to the appropriate type for `operator`.
pub const UnaryOperation = struct {
    operator: *Token,
    operand: *Expression,
};

pub const FunctionCall = struct {
    identifier: ScopedIdentifier,
    arguments: []*Expression,
};

pub const Declaration = struct {
    const_var: *Token,
    identifier: *Token,
    type: ?*Token,
    rhs: *Expression,
};

pub const Expression = union(enum) {
    literal: *Token,
    identifier: ScopedIdentifier,
    binary_operation: BinaryOperation,
    unary_operation: UnaryOperation,
    function_call: FunctionCall,
    // function_definition: FunctionDefinition,

    fn parse(allocator: Allocator, tokens: []Token) ParseError!*Expression {
        assert(tokens.len > 0);
        // The order in which we check for expression types is important.
        const result = try allocator.create(Expression);
        if (tokens.len == 1) switch (tokens[0].tag) {
            .string_literal, .integer_literal => {
                result.* = .{ .literal = &tokens[0] };
                return result;
            },
            .identifier => {
                // TODO special case this because we know it's already length 1
                result.* = .{ .identifier = try ScopedIdentifier.parse(allocator, tokens) };
                return result;
            },
            else => unreachable,
        };

        // (Maybe scoped) identifiers
        for (tokens) |t| {
            switch (t.tag) {
                .identifier, .dot => {},
                else => break,
            }
        } else {
            result.* = .{ .identifier = try ScopedIdentifier.parse(allocator, tokens) };
            return result;
        }

        // Precedence parentheses
        if (tokens[0].tag == .l_paren and tokens[tokens.len - 1].tag == .r_paren) {
            return Expression.parse(allocator, tokens[1 .. tokens.len - 2]);
        }

        // Unary operators
        {
            switch (tokens[0].tag) {
                .minus => {
                    result.* = .{
                        .unary_operation = .{
                            .operator = &tokens[0],
                            .operand = try Expression.parse(allocator, tokens[1..tokens.len]),
                        },
                    };
                    return result;
                },
                else => {},
            }
        }

        // Binary operators
        {
            const maybe_index = try scanTokensInScope(
                &[_]Token.Tag{ .plus, .minus, .forward_slash, .asterisk },
                tokens,
            );
            if (maybe_index) |index| {
                result.* = .{ .binary_operation = .{
                    .lhs = try Expression.parse(allocator, tokens[0..index]),
                    .rhs = try Expression.parse(allocator, tokens[index + 1 ..]),
                    .operator = &tokens[index],
                } };
                return result;
            }
        }

        // Function call
        {
            const has_parens = for (tokens) |t| {
                if (t.tag == .l_paren) break true;
            } else false;
            if (has_parens) {
                var index: usize = 0;
                while (true) : (index += 1) {
                    switch (tokens[index].tag) {
                        .identifier, .dot => {},
                        else => break,
                    }
                }
                if (tokens[index].tag == .l_paren and tokens[tokens.len - 1].tag == .r_paren) {
                    result.* = .{
                        .function_call = .{
                            .identifier = try ScopedIdentifier.parse(allocator, tokens[0..index]),
                            .arguments = undefined,
                        },
                    };
                    var list = ArrayList(*Expression).init(allocator);
                    var anchor: usize = 2;
                    var paren_depth: usize = 1;
                    for (tokens[2..], 2..) |t, i| {
                        switch (t.tag) {
                            .comma => {
                                if (paren_depth == 1) {
                                    // if (i == anchor + 1) std.debug.panic("expected expression", .{});
                                    try list.append(try Expression.parse(allocator, tokens[anchor..i]));
                                    anchor = i + 1;
                                }
                            },
                            .r_paren => {
                                if (paren_depth == 1) {
                                    try list.append(try Expression.parse(allocator, tokens[anchor..i]));
                                    result.function_call.arguments = try list.toOwnedSlice();
                                    return result;
                                } else paren_depth -= 1;
                            },
                            .l_paren => {
                                paren_depth += 1;
                            },
                            else => {},
                        }
                    }
                    return result;
                }
            }
        }

        std.debug.panic("couldn't parse expression", .{});

        unreachable;
    }
};

pub const Assignment = struct {
    lhs: *Token, // identifier
    rhs: *Expression,
};

pub const FunctionDeclaration = struct {
    identifier: *Token,
    arguments: []TypedIdentifier,
    return_type: *Token,
    block: *Block,
};

pub const Statement = union(enum) {
    assignment: Assignment,
    expression: *Expression,
    declaration: Declaration,
    // if
    // loops
    // etc

    fn parse(allocator: Allocator, tokens: []Token) ParseError!*Statement {
        if (tokens[tokens.len - 1].tag == .semicolon) {
            // Assignment and declaration
            // If there's an `=`, this is an assignment or a declaration, otherwise move on
            const maybe_index = try scanTokensInScope(&[_]Token.Tag{.single_equals}, tokens);
            if (maybe_index) |index| {
                // Check if this is a declaration
                if (tokens[0].tag == .keyword_const or tokens[0].tag == .keyword_var) {
                    if (tokens[2].tag != .colon)
                        std.debug.panic("i didn't implement this sort of decl yet sry", .{});
                    const result = try allocator.create(Statement);
                    result.* = .{
                        .declaration = .{
                            .const_var = &tokens[0],
                            .identifier = &tokens[1],
                            .type = &tokens[3],
                            .rhs = try Expression.parse(allocator, tokens[index + 1 .. tokens.len - 1]),
                        },
                    };
                    return result;
                } else { // Otherwise this is an assignment
                    const result = try allocator.create(Statement);
                    result.* = .{ .assignment = .{
                        .lhs = &tokens[0],
                        .rhs = try Expression.parse(allocator, tokens[index + 1 .. tokens.len - 1]),
                    } };
                    return result;
                }
            }

            // Expression
            const result = try allocator.create(Statement);
            // Parse this as an expression, without the semicolon on the end
            result.* = .{ .expression = try Expression.parse(allocator, tokens[0 .. tokens.len - 1]) };
            return result;
        }

        unreachable;
    }
};

pub const Block = struct {
    statements: []*Statement,

    /// `tokens` should be the stuff within the braces.
    fn parse(allocator: Allocator, tokens: []Token) ParseError!Block {
        var list = ArrayList(*Statement).init(allocator);
        var index: usize = 0;
        while (index < tokens.len - 1) {
            // `end` is the token after the last one contained in the slice we're currently parsing
            var end: usize = undefined;
            switch (tokens[index].tag) {
                // .keyword_if => {},
                // .keyword_while => {},
                // .keyword_for => {},
                // single line
                else => {
                    if (try scanTokensInScope(
                        &[_]Token.Tag{.semicolon},
                        tokens[index..],
                    )) |semicolon| {
                        end = index + semicolon + 1;
                    } else {
                        std.debug.panic("couldn't parse block", .{});
                    }
                },
            }
            try list.append(try Statement.parse(allocator, tokens[index..end]));
            index = end;
        }

        return .{
            .statements = try list.toOwnedSlice(),
        };
    }
};

fn expectAst(T: type, expected: []const u8, source: []const u8) !void {
    const pretty = @import("pretty");
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var tokenizer = try Tokenizer.init(allocator, source);
    const tokens = try tokenizer.tokenize();

    const tree = try T.parse(allocator, tokens);
    const actual = try pretty.dump(testing.allocator, tree, .{});
    defer testing.allocator.free(actual);
    try std.testing.expectEqualStrings(expected, actual);
}

test "block" {
    const source =
        \\const a: Int = 5;
        \\var b: Int = a;
        \\do_stuff(b);
    ;
    const expected =
        \\ast.Block
        \\  .statements: []*ast.Statement
        \\    [0]: *ast.Statement
        \\      .declaration: ast.Declaration
        \\        .const_var: *tokenization.Token
        \\          .tag: tokenization.Token.Tag
        \\            .keyword_const
        \\          .start: usize => 0
        \\          .end: usize => 5
        \\        .identifier: *tokenization.Token
        \\          .tag: tokenization.Token.Tag
        \\            .identifier
        \\          .start: usize => 6
        \\          .end: usize => 7
        \\        .type: ?*tokenization.Token
        \\          .tag: tokenization.Token.Tag
        \\            .identifier
        \\          .start: usize => 9
        \\          .end: usize => 12
        \\        .rhs: *ast.Expression
        \\          .literal: *tokenization.Token
        \\            .tag: tokenization.Token.Tag
        \\              .integer_literal
        \\            .start: usize => 15
        \\            .end: usize => 16
        \\    [1]: *ast.Statement
        \\      .declaration: ast.Declaration
        \\        .const_var: *tokenization.Token
        \\          .tag: tokenization.Token.Tag
        \\            .keyword_var
        \\          .start: usize => 18
        \\          .end: usize => 21
        \\        .identifier: *tokenization.Token
        \\          .tag: tokenization.Token.Tag
        \\            .identifier
        \\          .start: usize => 22
        \\          .end: usize => 23
        \\        .type: ?*tokenization.Token
        \\          .tag: tokenization.Token.Tag
        \\            .identifier
        \\          .start: usize => 25
        \\          .end: usize => 28
        \\        .rhs: *ast.Expression
        \\          .identifier: ast.ScopedIdentifier
        \\            .identifiers: []*tokenization.Token
        \\              .tag: tokenization.Token.Tag
        \\                .identifier
        \\              .start: usize => 31
        \\              .end: usize => 32
        \\    [2]: *ast.Statement
        \\      .expression: *ast.Expression
        \\        .function_call: ast.FunctionCall
        \\          .identifier: ast.ScopedIdentifier
        \\            .identifiers: []*tokenization.Token
        \\              .tag: tokenization.Token.Tag
        \\                .identifier
        \\              .start: usize => 34
        \\              .end: usize => 42
        \\          .arguments: []*ast.Expression
        \\            .identifier: ast.ScopedIdentifier
        \\              .identifiers: []*tokenization.Token
        \\                .tag: tokenization.Token.Tag
        \\                  .identifier
        \\                .start: usize => 43
        \\                .end: usize => 44
    ;
    try expectAst(Block, expected, source);
}

test "const declaration" {
    const source =
        \\const cats: Animal = 100;
    ;
    const expected =
        \\*ast.Statement
        \\  .declaration: ast.Declaration
        \\    .const_var: *tokenization.Token
        \\      .tag: tokenization.Token.Tag
        \\        .keyword_const
        \\      .start: usize => 0
        \\      .end: usize => 5
        \\    .identifier: *tokenization.Token
        \\      .tag: tokenization.Token.Tag
        \\        .identifier
        \\      .start: usize => 6
        \\      .end: usize => 10
        \\    .type: ?*tokenization.Token
        \\      .tag: tokenization.Token.Tag
        \\        .identifier
        \\      .start: usize => 12
        \\      .end: usize => 18
        \\    .rhs: *ast.Expression
        \\      .literal: *tokenization.Token
        \\        .tag: tokenization.Token.Tag
        \\          .integer_literal
        \\        .start: usize => 21
        \\        .end: usize => 24
    ;
    try expectAst(Statement, expected, source);
}

test "decimal integer literal" {
    const source =
        \\69_420
    ;
    const expected =
        \\*ast.Expression
        \\  .literal: *tokenization.Token
        \\    .tag: tokenization.Token.Tag
        \\      .integer_literal
        \\    .start: usize => 0
        \\    .end: usize => 6
    ;
    try expectAst(Expression, expected, source);
}

test "1 + 1" {
    const source =
        \\1 + 1
    ;
    const expected =
        \\*ast.Expression
        \\  .binary_operation: ast.BinaryOperation
        \\    .lhs: *ast.Expression
        \\      .literal: *tokenization.Token
        \\        .tag: tokenization.Token.Tag
        \\          .integer_literal
        \\        .start: usize => 0
        \\        .end: usize => 1
        \\    .operator: *tokenization.Token
        \\      .tag: tokenization.Token.Tag
        \\        .plus
        \\      .start: usize => 2
        \\      .end: usize => 3
        \\    .rhs: *ast.Expression
        \\      .literal: *tokenization.Token
        \\        .tag: tokenization.Token.Tag
        \\          .integer_literal
        \\        .start: usize => 4
        \\        .end: usize => 5
    ;
    try expectAst(Expression, expected, source);
}

test "function call with various arguments" {
    const source =
        \\do_stuff(another_function(0xabcd), "貓", 1234)
    ;
    const expected =
        \\*ast.Expression
        \\  .function_call: ast.FunctionCall
        \\    .identifier: ast.ScopedIdentifier
        \\      .identifiers: []*tokenization.Token
        \\        .tag: tokenization.Token.Tag
        \\          .identifier
        \\        .start: usize => 0
        \\        .end: usize => 8
        \\    .arguments: []*ast.Expression
        \\      [0]: *ast.Expression
        \\        .function_call: ast.FunctionCall
        \\          .identifier: ast.ScopedIdentifier
        \\            .identifiers: []*tokenization.Token
        \\              .tag: tokenization.Token.Tag
        \\                .identifier
        \\              .start: usize => 9
        \\              .end: usize => 25
        \\          .arguments: []*ast.Expression
        \\            .literal: *tokenization.Token
        \\              .tag: tokenization.Token.Tag
        \\                .integer_literal
        \\              .start: usize => 26
        \\              .end: usize => 32
        \\      [1]: *ast.Expression
        \\        .literal: *tokenization.Token
        \\          .tag: tokenization.Token.Tag
        \\            .string_literal
        \\          .start: usize => 35
        \\          .end: usize => 40
        \\      [2]: *ast.Expression
        \\        .literal: *tokenization.Token
        \\          .tag: tokenization.Token.Tag
        \\            .integer_literal
        \\          .start: usize => 42
        \\          .end: usize => 46
    ;
    try expectAst(Expression, expected, source);
}

test "unary minus" {
    const source =
        \\-1234
    ;
    const expected =
        \\*ast.Expression
        \\  .unary_operation: ast.UnaryOperation
        \\    .operator: *tokenization.Token
        \\      .tag: tokenization.Token.Tag
        \\        .minus
        \\      .start: usize => 0
        \\      .end: usize => 1
        \\    .operand: *ast.Expression
        \\      .literal: *tokenization.Token
        \\        .tag: tokenization.Token.Tag
        \\          .integer_literal
        \\        .start: usize => 1
        \\        .end: usize => 5
    ;
    try expectAst(Expression, expected, source);
}
