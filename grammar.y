Root <- ModuleMembers

ModuleDecl <- KEYWORD_module Identifier LBRACE ModuleMembers RBRACE

ModuleMembers <- (FnDecl / EnumDecl / IfaceDecl / GenericDecl / StructDecl / VarDecl / ModuleDecl)*

FnDecl <- KEYWORD_fn Identifier LPAREN ParamDeclList RPAREN Type CodeBlock

FnSignature <- KEYWORD_fn Identifier LPAREN ParamDeclList RPAREN Type Semicolon

Type <- 
	ScopedIdentifier
	/ (LBRACKET ScopedIdentifier RBRACKET)
	/ (LBRACE ScopedIdentifier COLON Type RBRACE)

StructDecl <- KEYWORD_struct Identifier LBRACE ((FnDecl / VarDecl / StructMember COMMA)* / 
	(StructMember COMMA)* StructMember?) RBRACE

# `name: Type,`
# `name: Type = default_value,`
StructMember <- Identifier COLON Type (EQUALS Literal)?

Literal <-

IfaceDecl <- KEYWORD_interface Identifier LBRACE FnSignature* RBRACE

GenericDecl <- KEYWORD_generic Identifier LESSTHAN Identifier GREATERTHAN LBRACE (FnDecl / VarDecl
	/ StructMember)* RBRACE

EnumDecl <- KEYWORD_enum Identifier LBRACE (EnumMember COMMA)* EnumMember? RBRACE

EnumMember <- Identifier (EQUALS IntegerLiteral)?

VarDecl <- (KEYWORD_const / KEYWORD_var) Identifier EQUALS Expression SEMICOLON

Expression <- 
	(Expression BinaryOperator Expression)
	/ (LPAREN Expression RPAREN)
	/ (UnaryOperator Expression)
	/ FunctionCall

BinaryOperator <-

UnaryOperator <-

# ParenExpression <- LPAREN Expression RPAREN

ParamDeclList <- (ParamDecl COMMA)* ParamDecl?

ParamDecl <- Identifier COLON Type

ScopedIdentifier <- Identifier (DOT Identifier)*
