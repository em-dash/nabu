# took a bunch of stuff from here: 
# https://github.com/ziglang/zig-spec/blob/75129c7a34010ead828055c26a6d41d1516faa97/grammar/grammar.y

Root <- ModuleMembers

ModuleDecl <- KEYWORD_module Identifier LBRACE ModuleMembers RBRACE

ModuleMembers <- (FunctionDecl / EnumDecl / IfaceDecl / GenericDecl / ClassDecl / VarDecl / ModuleDecl)*

FunctionDecl <- KEYWORD_fn Identifier LPAREN ParamDeclList RPAREN Type FunctionBody

FunctionSignature <- KEYWORD_fn Identifier LPAREN ParamDeclList RPAREN Type Semicolon

Type <- 
	ScopedIdentifier
	/ (LBRACKET ScopedIdentifier RBRACKET)
	/ (LBRACE ScopedIdentifier COLON Type RBRACE)

ClassDecl <- KEYWORD_class Identifier LBRACE ((FunctionDecl / VarDecl / ClassMember COMMA)* / 
	(ClassMember COMMA)* ClassMember?) RBRACE

# `name: Type,`
# `name: Type = default_value,`
ClassMember <- Identifier COLON Type (EQUALS Literal)?

Literal <-

IfaceDecl <- KEYWORD_interface Identifier LBRACE FunctionSignature* RBRACE

GenericDecl <- KEYWORD_generic Identifier LESSTHAN Identifier GREATERTHAN LBRACE (FunctionDecl / VarDecl
	/ ClassMember)* RBRACE

EnumDecl <- KEYWORD_enum Identifier LBRACE (EnumMember COMMA)* EnumMember? RBRACE

EnumMember <- Identifier (EQUALS IntegerLiteral)?

VarDecl <- (KEYWORD_const / KEYWORD_var) Identifier EQUALS Expression SEMICOLON

FunctionCall <- Identifier LPAREN (Expression COMMA)* Expression? RPAREN

Expression <- 
	(Expression BinaryOperator Expression)
	/ (LPAREN Expression RPAREN)
	/ (UnaryOperator Expression)
	/ FunctionCall


ParamDeclList <- (ParamDecl COMMA)* ParamDecl?

ParamDecl <- Identifier COLON Type

ScopedIdentifier <- Identifier (DOT Identifier)*

# tokens
ox80_oxBF <- [\200-\277]
oxF4 <- '\364'
ox80_ox8F <- [\200-\217]
oxF1_oxF3 <- [\361-\363]
oxF0 <- '\360'
ox90_0xBF <- [\220-\277]
oxEE_oxEF <- [\356-\357]
oxED <- '\355'
ox80_ox9F <- [\200-\237]
oxE1_oxEC <- [\341-\354]
oxE0 <- '\340'
oxA0_oxBF <- [\240-\277]
oxC2_oxDF <- [\302-\337]

# From https://lemire.me/blog/2018/05/09/how-quickly-can-you-check-that-a-string-is-valid-unicode-utf-8/
# First Byte      Second Byte     Third Byte      Fourth Byte
# [0x00,0x7F]
# [0xC2,0xDF]     [0x80,0xBF]
#    0xE0         [0xA0,0xBF]     [0x80,0xBF]
# [0xE1,0xEC]     [0x80,0xBF]     [0x80,0xBF]
#    0xED         [0x80,0x9F]     [0x80,0xBF]
# [0xEE,0xEF]     [0x80,0xBF]     [0x80,0xBF]
#    0xF0         [0x90,0xBF]     [0x80,0xBF]     [0x80,0xBF]
# [0xF1,0xF3]     [0x80,0xBF]     [0x80,0xBF]     [0x80,0xBF]
#    0xF4         [0x80,0x8F]     [0x80,0xBF]     [0x80,0xBF]

mb_utf8_literal <-
       oxF4      ox80_ox8F ox80_oxBF ox80_oxBF
     / oxF1_oxF3 ox80_oxBF ox80_oxBF ox80_oxBF
     / oxF0      ox90_0xBF ox80_oxBF ox80_oxBF
     / oxEE_oxEF ox80_oxBF ox80_oxBF
     / oxED      ox80_ox9F ox80_oxBF
     / oxE1_oxEC ox80_oxBF ox80_oxBF
     / oxE0      oxA0_oxBF ox80_oxBF
     / oxC2_oxDF ox80_oxBF

ascii_char_not_nl_slash_squote <- [\000-\011\013-\046\050-\133\135-\177]

char_escape
    <- "\\x" hex hex
     / "\\u{" hex+ "}"
     / "\\" [nr\\t'"]
char_char
    <- mb_utf8_literal
     / char_escape
     / ascii_char_not_nl_slash_squote

string_char <- char_escape / [^\\"\n]

id_char <- char_escape / [^\`\n]

IDENTIFIER <- (!keyword [A-Za-z_] [A-Za-z0-9_]* skip) / BACKTICK id_char BACKTICK

eof <- !.
doc_comment <- ('///' [^\n]* [ \n]* skip)+
line_comment <- '//' ![!/][^\n]* / '////' [^\n]*
skip <- ([ \n\r] / line_comment)

end_of_word <- ![a-zA-Z0-9_] skip
KEYWORD_module <- 'module' end_of_word
KEYWORD_interface <- 'interface' end_of_word
KEYWORD_generic <- 'generic' end_of_word
KEYWORD_enum <- 'enum' end_of_word
KEYWORD_fn <- 'fn' end_of_word
KEYWORD_class <- 'class' end_of_word
KEYWORD_var <- 'var' end_of_word
KEYWORD_const <- 'const' end_of_word
KEYWORD_this <- 'this' end_of_word
KEYWORD_z <- 'z' end_of_word
KEYWORD_z <- 'z' end_of_word
KEYWORD_z <- 'z' end_of_word
KEYWORD_z <- 'z' end_of_word
KEYWORD_z <- 'z' end_of_word
KEYWORD_z <- 'z' end_of_word
KEYWORD_z <- 'z' end_of_word
