# Kotlin Idioms (Official)

Source: https://kotlinlang.org/docs/idioms.html
Fetched: 2026-03-25

## Key idioms (summary)

### Collection presence
```kotlin
if ("john@example.com" in emailsList) { ... }
if ("jane@example.com" !in emailsList) { ... }
```

### Read-only collections
```kotlin
val list = listOf("a", "b", "c")
val map = mapOf("a" to 1, "b" to 2, "c" to 3)
```

### Destructuring in iteration
```kotlin
for ((k, v) in map) { println("$k -> $v") }
```

### Ranges
```kotlin
for (i in 1..100) { }       // closed: includes 100
for (i in 1..<100) { }      // open: excludes 100
for (x in 2..10 step 2) { }
for (x in 10 downTo 1) { }
```

### Lazy property
```kotlin
val p: String by lazy { expensiveComputation() }
```

### Inline value class (type-safe primitives)
```kotlin
@JvmInline value class UserId(private val id: Long)
@JvmInline value class OrderId(private val id: Long)
// Mixing UserId/OrderId is a compile error
```

### Complex null fallback with run
```kotlin
val size = files?.size ?: run {
    log.warn("files is null")
    0
}
```

### try-catch as expression
```kotlin
val result = try { parse(input) } catch (e: ParseException) { null }
```

### if as expression
```kotlin
val label = if (score >= 90) "Excellent" else "Good"
```

### use for AutoCloseable
```kotlin
Files.newInputStream(path).buffered().reader().use { println(it.readText()) }
```

### Safe type conversions at boundaries
```kotlin
val id = input.toLongOrNull() ?: throw IllegalArgumentException("Invalid id: $input")
```

### inline reified for generic type info
```kotlin
inline fun <reified T : Any> ObjectMapper.readValue(json: String): T =
    readValue(json, T::class.java)
```

### TODO() for stubs
```kotlin
fun calcTaxes(): BigDecimal = TODO("Waiting for feedback from accounting")
```
