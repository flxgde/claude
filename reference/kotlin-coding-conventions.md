# Kotlin Coding Conventions (Official)

Source: https://kotlinlang.org/docs/coding-conventions.html
Fetched: 2026-03-25

## Naming

### Packages
- Lowercase, no underscores: `org.example.project`

### Classes / Objects
- Upper camel case: `DeclarationProcessor`, `EmptyDeclarationProcessor`

### Functions / Properties / Local variables
- Lowercase camel case, no underscores: `processDeclarations`, `declarationCount`

### Constants (const val, top-level/object val with no custom getter)
- SCREAMING_SNAKE_CASE: `const val MAX_COUNT = 8`, `val USER_NAME_FIELD = "UserName"`

### Backing properties
- Underscore prefix for private backing: `private val _elementList`, `val elementList: List<Element> get() = _elementList`

### Enum constants
- Either SCREAMING_SNAKE_CASE or UpperCamelCase

### Test methods
- Backtick names: `` fun `ensure everything works`() ``
- Or underscore: `fun ensureEverythingWorks_onAndroid()`

### Acronyms
- 2 letters: uppercase both: `IOStream`
- 3+ letters: capitalize first only: `XmlFormatter`, `HttpInputStream`

## Formatting

- 4 spaces, no tabs
- Opening brace on same line
- Trailing commas encouraged (cleaner diffs, easier reorder)
- `.` and `?.` on next line for chained calls

## Idiomatic Use

### Loops
- Prefer higher-order functions (`filter`, `map`, etc.) over loops
- **Exception: use `for` loop instead of `forEach`** for simple iteration

### Immutability
- Prefer `val` over `var`
- Use `List` / `Set` / `Map` return types over `ArrayList` / `HashSet`

### Default parameter values
- Prefer over overloaded functions

### Named arguments
- Use when multiple params of same type or Boolean params

### if vs when
- `if` for binary condition
- `when` for 3+ options

### Ranges
- Use `..<` for open-ended (exclusive upper bound): `for (i in 0..<n)`

### String templates
- Simple variable: `"$name"` (no braces)
- Expression: `"${children.size}"` (braces required)

### Extension functions
- Use liberally; restrict visibility as needed

### Type aliases
- Define for frequently used function types: `typealias MouseClickHandler = (Any, MouseEvent) -> Unit`

### Scope functions (let/run/with/apply/also)
- See: https://kotlinlang.org/docs/scope-functions.html for choosing the right one

### Factory functions
- OK to name same as abstract return type: `fun Foo(): Foo = FooImpl()`
- Prefer descriptive names for companion factories: `Point.fromPolar(angle, radius)`

### Lambda `it` convention
- Use `it` for short, non-nested lambdas
- Declare explicit param name for nested lambdas

### Properties vs functions
- Prefer property when: doesn't throw, cheap to compute, returns same value for same state

### Platform types (Java interop)
- Public functions must declare explicit Kotlin return type
