# syntax etc
- https://unicode.org/reports/tr31/#Immutable_Identifier_Syntax
## general
###
```
// comment
// just copy comment syntax from zig
```
### assignment and declaration
```
var a = 5; // mutable variable
const b = 2; // constant

const name: Explicit_Type = foo();

const f = fn(param: Type) Return_Type {}; // zig 1717 syntax lol
```
### math
```
const a = 1 + 1;
const b = 1 - 1;
const c = 1 / 1;
const d = 1 * 1;
```
### types
```
```
### slices and ranges
```
```
## interactive
### do not keep bruh moment from python, node, etc
`exit` and `quit` do what they say because why the hell wouldn't they
```
repl> exit
$ █
```
# style guide
- lines longer wider than 100 characters will cause a compile error
- snake case `function_call()`, `variable_name`, `enum_member`, `struct_member`
- wat case `Type_Name`

# compiler design
- assume u32
