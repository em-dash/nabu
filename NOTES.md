# modules
- (namespaces basically)
- by default each file is a module
- want to declare a module anyway for a laugh?  we have a tool for that, it's:
```
module name_of_module {
    // stuff in module
}
```
- namespaced stuff accessed with dot syntax
```
std.whatever.blah.lol();
this.that.yon.value = 5;
```
- use the keyword `using` to slurp another namespace into this one:
```
using blah;
```
# syntax etc
- https://unicode.org/reports/tr31/#Immutable_Identifier_Syntax
### comments
```
// comment
/// three slashes before basically whatever is a doc comment
```
### assignment and declaration
```
var a = 5; // mutable variable
const b = 2; // constant

const name: Explicit_Type = foo();

// anonymous containers
const a: Some_Struct_Type = ~{ .field = gimme_a_value() };

fn f(param: Type) Return_Type {
    // do stuff
}

// builtin fancy types:
var lol: [Int] = [420, 69, 9001]; // list
var bruh: String = "plus ça change plus c'est la même chose";
var number_words: {Int: String} = { 1: "one", 2: "two", 3: "three" }; // map

/// Struct decl
struct Some_Struct {
    field: Field_Type,
    field_with_default: Another_Type = default_value(),

    const scoped_value = "blep";
    var mutable_scoped_value = 5;

    fn scoped_function(param: Type) Return_Type {
        // do stuff
    }

    /// Assuming `foo` is an instance of `Some_Struct`, this can be called like 
    /// `foo.function_with_self()`.
    fn function_with_self(self: Some_Struct) Some_Struct {
        // do stuff
    }
}

enum Name {
    marten,
    red_panda,
    capybara,
}
// scoped fns callable with dot syntax like structs

interface Name {
    fn bork(param: Type) Return_Type;
    member: Member_Type,
}
// interface polymorphism pls

// generics
generic Pog<T> {
    member: T = foo(),
    another_member: [5]T,
}

var l: List<Doggo> = ~{};
```
### math
```
const a = 1 + 1;
const b = 1 - 1;
const c = 1 / 1;
const d = 1 * 1;
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
## variables
### reference and value semantics
base this on what go does; if you do `var a = get_value();`:
- `a` goes on the stack by default
- if `a` is a big boi, it goes on the heap
- if `a` _escapes_ (i.e. pointers to `a` would end up dangling when the stack frame containing `a` is popped), then it goes on the heap
you can get a reference to a thing by saying `var b = &a`
- either way, you can always treat `a` like a stack value in the relevant scope, and you can use `&a` to get a reference to it
# style guide
- lines longer wider than 100 characters will cause a compile error
- snake case `function_call()`, `variable_name`, `enum_member`, `struct_member`
- wat case `Type_Name`

# compiler design
- assume u32
# runtime design
- all the scripting language's memory (ie objects created and used by the program being run) is in a contiguous chunk, and is address in 32-bit words
    - bools would be pretty gross, but those are one-offs
    - arrays, maps, etc can be optimized fit the actual size of the type
- green threads?  (also why are they called that)
