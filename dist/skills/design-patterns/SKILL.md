---
name: design-patterns
description: Design patterns with idiomatic Kotlin examples — Builder, Factory, Strategy, Observer, Decorator, Singleton, Repository, and Result/Either. Use when designing extensible components, refactoring rigid code, or when a user asks to implement a specific pattern.
---

# Design Patterns in Kotlin

## Quick Reference

| Problem | Pattern | Kotlin approach |
|---|---|---|
| Many optional constructor params | **Builder** | `data class` + default values + `.copy()` |
| Create objects without specifying class | **Factory** | `companion object` or top-level function |
| Multiple algorithms, swap at runtime | **Strategy** | Function type `(T) -> R` or interface |
| Notify multiple objects of changes | **Observer** | `Flow` or callback list |
| Add behavior without changing class | **Decorator** | Extension functions or `by` delegation |
| One instance only | **Singleton** | `object` keyword |
| Data access abstraction | **Repository** | Spring Data interface |
| Express success/failure without exceptions | **Result/Either** | `sealed class` |

---

## Builder → data class + copy()

Kotlin data classes with default values eliminate the Builder pattern in most cases.

```kotlin
// ❌ Java-style Builder
class EmailBuilder {
    private var to: String = ""
    private var subject: String = ""
    private var body: String = ""
    private var cc: List<String> = emptyList()

    fun to(to: String) = apply { this.to = to }
    fun subject(subject: String) = apply { this.subject = subject }
    // ...
    fun build() = Email(to, subject, body, cc)
}

// ✅ Kotlin — data class with defaults
data class Email(
    val to: String,
    val subject: String,
    val body: String = "",
    val cc: List<String> = emptyList(),
    val bcc: List<String> = emptyList()
)

// Usage — named args, no builder needed
val email = Email(
    to = "user@example.com",
    subject = "Welcome"
)

// Modify immutably
val withBody = email.copy(body = "Hello!")
```

**When to still use Builder:** Complex construction with validation that must run during build, or when the API will be called from Java.

---

## Factory → companion object

```kotlin
// ✅ Companion object factory
class Connection private constructor(
    val host: String,
    val port: Int,
    val ssl: Boolean
) {
    companion object {
        fun http(host: String) = Connection(host, 80, false)
        fun https(host: String) = Connection(host, 443, true)
        fun custom(host: String, port: Int, ssl: Boolean) = Connection(host, port, ssl)
    }
}

// Usage
val conn = Connection.https("api.example.com")

// ✅ Top-level factory function (simpler, no companion needed)
fun createHttpClient(baseUrl: String, timeout: Duration = Duration.ofSeconds(30)): HttpClient =
    HttpClient.builder()
        .baseUrl(baseUrl)
        .timeout(timeout)
        .build()
```

---

## Strategy → function type

```kotlin
// ❌ Interface-based (verbose for simple cases)
interface PricingStrategy {
    fun calculate(basePrice: BigDecimal): BigDecimal
}
class StandardPricing : PricingStrategy { ... }
class DiscountPricing(val discount: Double) : PricingStrategy { ... }

// ✅ Function type — Strategy is just a lambda
typealias PricingStrategy = (BigDecimal) -> BigDecimal

val standard: PricingStrategy = { price -> price }
val tenPercentOff: PricingStrategy = { price -> price * BigDecimal("0.90") }
val vipDiscount: PricingStrategy = { price -> price * BigDecimal("0.80") }

// Service takes the strategy as a parameter
class OrderService {
    fun calculateTotal(items: List<OrderItem>, strategy: PricingStrategy): BigDecimal =
        items.sumOf { strategy(it.basePrice) }
}

// Usage
orderService.calculateTotal(items, tenPercentOff)
```

**Use interface-based Strategy when:** The strategy has multiple methods, needs to carry significant state, or is a Spring bean.

---

## Observer → Flow / callback

```kotlin
// ✅ Kotlin Flow for async event streams
class OrderEventPublisher {
    private val _events = MutableSharedFlow<OrderEvent>(extraBufferCapacity = 64)
    val events: SharedFlow<OrderEvent> = _events.asSharedFlow()

    suspend fun publish(event: OrderEvent) { _events.emit(event) }
}

// Subscriber
class NotificationService(private val publisher: OrderEventPublisher) {
    fun startListening() {
        CoroutineScope(Dispatchers.IO).launch {
            publisher.events
                .filterIsInstance<OrderEvent.Created>()
                .collect { sendConfirmationEmail(it.order) }
        }
    }
}

// ✅ Simple callback list (synchronous, no coroutines needed)
class EventBus<T> {
    private val listeners = mutableListOf<(T) -> Unit>()

    fun subscribe(listener: (T) -> Unit) { listeners.add(listener) }
    fun publish(event: T) { listeners.forEach { it(event) } }
}
```

---

## Decorator → extension functions or `by` delegation

```kotlin
// ✅ Extension function decorator — add behavior without wrapping
fun UserRepository.findActiveOrThrow(id: Long): User =
    findById(id)
        .filter { it.active }
        .orElseThrow { EntityNotFoundException("Active user $id not found") }

// ✅ Class delegation with `by` — wrap without boilerplate
interface Cache<K, V> {
    fun get(key: K): V?
    fun put(key: K, value: V)
    fun evict(key: K)
}

class LoggingCache<K, V>(private val delegate: Cache<K, V>) : Cache<K, V> by delegate {
    private val log = KotlinLogging.logger {}

    // Override only what changes; everything else is delegated automatically
    override fun get(key: K): V? =
        delegate.get(key).also { value ->
            if (value != null) log.debug { "Cache hit: key=$key" }
            else log.debug { "Cache miss: key=$key" }
        }
}
```

---

## Singleton → `object`

```kotlin
// ✅ Kotlin object — thread-safe, lazy-initialized singleton
object DatabaseConfig {
    val url: String = System.getenv("DB_URL") ?: "jdbc:postgresql://localhost:5432/db"
    val maxPoolSize: Int = 10
}

// ✅ Companion object singleton with dependency
class AppConfig private constructor(val apiKey: String) {
    companion object {
        @Volatile private var instance: AppConfig? = null

        fun getInstance(apiKey: String) = instance ?: synchronized(this) {
            instance ?: AppConfig(apiKey).also { instance = it }
        }
    }
}

// In Spring Boot — just use @Component / @Service; Spring manages singleton lifecycle
```

---

## Result / Either → sealed class

```kotlin
sealed class Result<out T> {
    data class Success<T>(val value: T) : Result<T>()
    data class Failure(val error: AppError) : Result<Nothing>()
}

sealed class AppError {
    data class NotFound(val id: Long, val type: String) : AppError()
    data class ValidationError(val message: String) : AppError()
    data class Conflict(val message: String) : AppError()
}

// Service — no exceptions for expected failures
fun getUser(id: Long): Result<UserResponse> =
    userRepository.findById(id)
        .map { Result.Success(it.toResponse()) }
        .orElse(Result.Failure(AppError.NotFound(id, "User")))

// Controller — exhaustive when maps to HTTP
fun getUser(@PathVariable id: Long): ResponseEntity<*> =
    when (val result = userService.getUser(id)) {
        is Result.Success -> ResponseEntity.ok(result.value)
        is Result.Failure -> when (val error = result.error) {
            is AppError.NotFound -> ResponseEntity.notFound().build()
            is AppError.ValidationError -> ResponseEntity.badRequest().body(error.message)
            is AppError.Conflict -> ResponseEntity.status(409).body(error.message)
        }
    }
```

---

## Repository → Spring Data

```kotlin
// ✅ Spring Data does the heavy lifting
interface UserRepository : JpaRepository<User, Long> {
    fun findByEmail(email: String): Optional<User>
    fun findByStatusOrderByCreatedAtDesc(status: UserStatus): List<User>

    @Query("SELECT u FROM User u WHERE u.role = :role AND u.active = true")
    fun findActiveByRole(@Param("role") role: Role): List<User>
}

// Custom implementation for complex queries
interface UserRepositoryCustom {
    fun findBySearchCriteria(criteria: UserSearchCriteria): Page<User>
}

@Repository
class UserRepositoryCustomImpl(private val em: EntityManager) : UserRepositoryCustom {
    override fun findBySearchCriteria(criteria: UserSearchCriteria): Page<User> {
        // JPQL or Criteria API for dynamic queries
    }
}

// Combine both
interface UserRepository : JpaRepository<User, Long>, UserRepositoryCustom
```
