---
name: kotlin-patterns
description: Kotlin idioms for Spring Boot development — null safety, data classes, extension functions, scope functions, naming conventions, kotlinx.serialization, and Kotlin-idiomatic Spring patterns. Aligned with official Kotlin coding conventions. Use when writing or reviewing Kotlin backend code.
---

# Kotlin Patterns for Spring Boot

Reference: https://kotlinlang.org/docs/coding-conventions.html

## Naming Conventions

```kotlin
// Packages — lowercase, no underscores
package de.flxg.order.service

// Classes / Objects — UpperCamelCase
class OrderService
object EmptyProcessor

// Functions / properties / local variables — lowerCamelCase
fun processOrder() { }
val declarationCount = 1

// Constants (const val, top-level/object val with no getter) — SCREAMING_SNAKE_CASE
const val MAX_RETRY_COUNT = 3
val USER_NAME_FIELD = "UserName"

// Backing properties — underscore prefix for private backing field
class Repository {
    private val _results = mutableListOf<Result>()
    val results: List<Result> get() = _results
}

// Acronyms — 2 letters all-caps, 3+ letters capitalize first only
class IOStream       // 2-letter acronym
class XmlFormatter   // 3+ letter acronym
class HttpInputStream
```

### Test method names
```kotlin
// ✅ Backtick names (preferred for JVM)
@Test
fun `should return 404 when user does not exist`() { }

// ✅ Underscore variant (required for Android API < 30)
@Test
fun getUserById_returnsUser_whenFound() { }
```

---

## Null Safety

```kotlin
// ❌ Java-style
if (user != null) { return user.email } else { return "unknown" }

// ✅ Kotlin
return user?.email ?: "unknown"

// ❌ Force-unwrap — avoid
val user = findUser()!!

// ✅ Fail with meaningful message
val user = findUser() ?: error("User must exist at this point")

// ✅ Validate at boundary (controller input)
val id = request.userId ?: throw IllegalArgumentException("userId is required")
```

**Rule:** `!!` is a code smell. Replace with `?: throw` or `?: error()`.

---

## Data Classes

Use for **DTOs, request/response models, value objects**. Do NOT use for JPA entities.

```kotlin
// ✅ DTO — trailing commas encouraged (cleaner diffs)
data class CreateUserRequest(
    val name: String,
    val email: String,
    val role: UserRole = UserRole.USER,  // trailing comma
)

// ✅ Immutable update
val updated = original.copy(email = "new@example.com")

// ❌ JPA entity as data class — hashCode/equals on mutable fields breaks Set/Hibernate proxies
@Entity
data class User(...)  // avoid

// ✅ JPA entity as regular class
@Entity
@Table(name = "users")
class User(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,
    var name: String,
    var email: String,
)
```

---

## Loops and Iteration

**Official convention:** prefer higher-order functions (`map`, `filter`, etc.) over loops.
**Exception: use `for` loop instead of `forEach`** for simple iteration.

```kotlin
// ✅ Higher-order functions — transform, filter, aggregate
val emails = users.map { it.email }
val admins = users.filter { it.role == Role.ADMIN }
val totalOrders = orders.sumOf { it.total }
val allItems = orders.flatMap { it.items }
val byRole: Map<Role, List<User>> = users.groupBy { it.role }
val usersById: Map<Long, User> = users.associateBy { it.id }
val admin = users.firstOrNull { it.role == Role.ADMIN }
val hasAdmin = users.any { it.role == Role.ADMIN }

// ✅ for loop for simple iteration (NOT forEach)
for (user in users) {
    process(user)
}

// ❌ forEach — avoid for simple iteration per official convention
users.forEach { process(it) }

// ✅ Open-ended range — use ..<  not  ..n-1
for (i in 0..<size) { }
```

---

## Extension Functions for Mapping

```kotlin
// In User.kt or UserMappings.kt next to the entity
fun User.toResponse() = UserResponse(
    id = id,
    name = name,
    email = email,
)

fun CreateUserRequest.toEntity() = User(
    name = name,
    email = email,
)

// Usage in service — reads naturally
return userRepository.save(request.toEntity()).toResponse()
```

---

## Scope Functions

| Function | Receiver | Returns | Use when |
|---|---|---|---|
| `let` | `it` | lambda result | Null-safe call chain, transform nullable |
| `run` | `this` | lambda result | Object config + compute result |
| `apply` | `this` | receiver | Object initialization / builder |
| `also` | `it` | receiver | Side effect (logging, validation) without changing chain |
| `with` | `this` | lambda result | Multiple calls on non-nullable object |

```kotlin
// let — null-safe transform
user?.let { sendWelcomeEmail(it.email) }

// apply — builder-style initialization
val headers = HttpHeaders().apply {
    set("Authorization", "Bearer $token")
    contentType = MediaType.APPLICATION_JSON
}

// also — side effect that doesn't change the chain
return userRepository.save(user)
    .also { log.info("User created: id=${it.id}") }
    .toResponse()

// with — multiple ops on same object
with(user) {
    validate()
    updateLastLogin()
    notifyAdmin()
}
```

Use `it` for short, non-nested lambdas. Declare explicit names for nested lambdas.

---

## Type Aliases

Define for frequently used function or parameterized types.

```kotlin
typealias PricingStrategy = (BigDecimal) -> BigDecimal
typealias UserId = Long
typealias UserIndex = Map<Long, User>

// Usage
fun applyPricing(price: BigDecimal, strategy: PricingStrategy): BigDecimal = strategy(price)

val tenPercentOff: PricingStrategy = { price -> price * BigDecimal("0.90") }
```

---

## Sealed Classes for Results

```kotlin
sealed class UserResult {
    data class Success(val user: UserResponse) : UserResult()
    data class NotFound(val id: Long) : UserResult()
    data class ValidationError(val message: String) : UserResult()
}

fun getUser(id: Long): UserResult =
    userRepository.findById(id)
        .map { UserResult.Success(it.toResponse()) }
        .orElse(UserResult.NotFound(id))

// Exhaustive when — compiler enforces all cases
fun handle(result: UserResult): ResponseEntity<*> = when (result) {
    is UserResult.Success -> ResponseEntity.ok(result.user)
    is UserResult.NotFound -> ResponseEntity.notFound().build()
    is UserResult.ValidationError -> ResponseEntity.badRequest().body(result.message)
}
```

---

## `when` Expressions

```kotlin
// Use when for 3+ options (if for binary)
fun describeRole(role: Role): String = when (role) {
    Role.ADMIN -> "Administrator"
    Role.USER -> "Regular user"
    Role.GUEST -> "Guest"
}

// With conditions
fun classify(score: Int) = when {
    score >= 90 -> "Excellent"
    score >= 70 -> "Good"
    else -> "Needs improvement"
}
```

---

## Companion Objects / Factory Functions

```kotlin
// Descriptive factory names (preferred over generic "create")
class Connection private constructor(val host: String, val port: Int, val ssl: Boolean) {
    companion object {
        fun http(host: String) = Connection(host, 80, false)
        fun https(host: String) = Connection(host, 443, true)
    }
}

// Constants
object AppConstants {
    const val MAX_RETRY_COUNT = 3
    const val DEFAULT_PAGE_SIZE = 20
}
```

---

## kotlinx.serialization

```kotlin
// build.gradle.kts
plugins { kotlin("plugin.serialization") version kotlinVersion }
dependencies { implementation("org.jetbrains.kotlinx:kotlinx-serialization-json") }

@Serializable
data class UserResponse(
    val id: Long,
    val name: String,
    @SerialName("email_address") val email: String,  // custom JSON key
    @Transient val internalField: String = "",        // excluded from JSON
)
```

**Rule:** No `@JsonProperty`, `@JsonIgnore`, `@JsonAlias` — those are Jackson. Use `@SerialName` and `@Transient` from kotlinx.serialization.

---

## Idioms

### Collection presence — use `in` / `!in`
```kotlin
// ✅ Idiomatic
if (email in allowedEmails) { ... }
if (role !in permittedRoles) throw AccessDeniedException("Role not permitted")

// ❌ Verbose
if (allowedEmails.contains(email)) { ... }
```

### Destructuring in iteration
```kotlin
// Map entries
for ((key, value) in configMap) {
    log.debug { "Config: $key = $value" }
}

// Data class destructuring
val (name, email) = user
val (id, _, status) = order  // _ skips a component
```

### Ranges with step and downTo
```kotlin
for (i in 1..100) { }          // closed: 1 to 100 inclusive
for (i in 1..<100) { }         // open: 1 to 99
for (x in 0..10 step 2) { }    // 0, 2, 4, 6, 8, 10
for (x in 10 downTo 1) { }     // 10, 9, ..., 1
```

### Lazy property
```kotlin
// Computed once on first access, cached afterwards
val expensiveConfig: Config by lazy {
    loadConfigFromDatabase()
}
```

Useful for beans with expensive initialization that may not always be needed.

### Inline value classes — type-safe IDs
Prevents accidentally mixing up primitive IDs at compile time.

```kotlin
@JvmInline value class UserId(val value: Long)
@JvmInline value class OrderId(val value: Long)

fun getOrder(orderId: OrderId): Order { ... }

// Compile error — can't pass UserId where OrderId is expected
getOrder(UserId(42L))  // ❌ type mismatch
getOrder(OrderId(42L)) // ✅
```

Use for entity IDs, external reference codes, and any primitive that has a distinct domain meaning.

### Complex null fallback with `run`
```kotlin
// Simple fallback
val size = files?.size ?: 0

// Complex fallback — use run block
val size = files?.size ?: run {
    log.warn { "Files list is null, defaulting to 0" }
    0
}
```

### `try-catch` and `if` as expressions
```kotlin
// try-catch as expression
val parsed = try {
    objectMapper.readValue<UserResponse>(json)
} catch (e: JsonProcessingException) {
    null
}

// if as expression
val label = if (score >= 90) "Excellent" else "Good"
val response = if (user != null) ResponseEntity.ok(user) else ResponseEntity.notFound().build()
```

### Safe conversions at system boundaries
```kotlin
// Prefer XxxOrNull() over Xxx() to avoid exceptions on bad input
val id = pathVariable.toLongOrNull()
    ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid id: $pathVariable")

val status = runCatching { UserStatus.valueOf(param) }.getOrNull()
    ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Unknown status: $param")
```

### `use` for resource management
```kotlin
// AutoCloseable is closed automatically even on exception
Files.newInputStream(path).buffered().reader().use { reader ->
    return reader.readText()
}
```

### `inline fun <reified T>` for generic type info
```kotlin
// Reified avoids passing Class<T> explicitly
inline fun <reified T : Any> String.parseJson(): T =
    objectMapper.readValue(this, T::class.java)

// Usage
val user = jsonString.parseJson<UserResponse>()
```

### `TODO()` for explicit stubs
```kotlin
fun calcTaxes(): BigDecimal = TODO("Waiting for tax rule spec from business")
// Throws NotImplementedError at runtime — better than returning a wrong value silently
```

---

## Spring Boot Patterns

```kotlin
// Constructor injection — always; never @Autowired on fields
@Service
class UserService(
    private val userRepository: UserRepository,
    private val emailService: EmailService,
)

// Type-safe config
@ConfigurationProperties(prefix = "app.mail")
data class MailProperties(
    val host: String,
    val port: Int = 587,
    val from: String,
)

// Mockito-Kotlin in tests
whenever(userRepository.findById(1L)).thenReturn(Optional.of(testUser))
```
