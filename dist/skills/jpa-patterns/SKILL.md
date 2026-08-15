---
name: jpa-patterns
description: JPA/Hibernate patterns and pitfalls for Kotlin/Spring Boot — N+1, lazy loading, transactions, projections, pagination, optimistic locking. Use when working with Spring Data JPA, diagnosing query performance, or designing entity relationships.
---

# JPA Patterns for Kotlin/Spring Boot

## Entity Definition in Kotlin

JPA requires a no-arg constructor and mutable fields. Use a regular class, not a data class.

```kotlin
// ✅ Correct — regular class with default values (enables no-arg constructor via plugin)
@Entity
@Table(name = "users")
class User(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    @Column(nullable = false)
    var name: String,

    @Column(nullable = false, unique = true)
    var email: String,

    @Enumerated(EnumType.STRING)
    var status: UserStatus = UserStatus.ACTIVE
) {
    // Relationships defined in the body, not constructor
    @OneToMany(mappedBy = "user", cascade = [CascadeType.ALL], fetch = FetchType.LAZY)
    val orders: MutableList<Order> = mutableListOf()
}

// ❌ Avoid data class for entities — hashCode() on mutable fields breaks Set/HashMap
// and Hibernate proxying conflicts with data class copy()
```

**Required Gradle plugin** for no-arg constructor:
```kotlin
// build.gradle.kts
plugins {
    kotlin("plugin.jpa") version kotlinVersion
    kotlin("plugin.spring") version kotlinVersion  // opens Spring-required classes
}
```

---

## N+1 Problem

The most common JPA performance killer.

```kotlin
// ❌ N+1: loads all orders, then fires one SELECT per order to load items
val orders = orderRepository.findAll()
for (order in orders) {
    println(order.items.size)  // N additional queries here — one per order
}

// ✅ JOIN FETCH — one query with JOIN
@Query("SELECT o FROM Order o JOIN FETCH o.items WHERE o.status = :status")
fun findByStatusWithItems(@Param("status") status: String): List<Order>

// ✅ @EntityGraph — declarative fetch override
@EntityGraph(attributePaths = ["items", "items.product"])
fun findAllWithItems(): List<Order>
```

**Detection:** Enable SQL logging in development:
```yaml
# application.yml
spring:
  jpa:
    show-sql: true
    properties:
      hibernate:
        format_sql: true
logging:
  level:
    org.hibernate.SQL: DEBUG
    org.hibernate.orm.jdbc.bind: TRACE
```

---

## LazyInitializationException

Occurs when accessing a lazy-loaded collection outside a transaction.

```kotlin
// ❌ Transaction ends before accessing lazy collection
fun getOrderSummary(id: Long): String {
    val order = orderRepository.findById(id).orElseThrow()
    return order.items.size.toString()  // exception here — session closed
}

// ✅ Option 1: Use JOIN FETCH to load eagerly when needed
@Query("SELECT o FROM Order o JOIN FETCH o.items WHERE o.id = :id")
fun findByIdWithItems(@Param("id") id: Long): Optional<Order>

// ✅ Option 2: DTO projection (no entity involved)
@Query("SELECT new de.flxg.order.OrderSummary(o.id, SIZE(o.items)) FROM Order o WHERE o.id = :id")
fun findSummaryById(@Param("id") id: Long): Optional<OrderSummary>

// ✅ Option 3: Interface projection
interface OrderSummary {
    val id: Long
    val itemCount: Int
}
fun findSummaryById(id: Long): Optional<OrderSummary>
```

---

## Transaction Management

```kotlin
// ✅ Class-level readOnly default, override for writes
@Service
@Transactional(readOnly = true)
class OrderService(private val orderRepository: OrderRepository) {

    fun getById(id: Long): OrderResponse =
        orderRepository.findById(id)
            .map { it.toResponse() }
            .orElseThrow { EntityNotFoundException("Order $id not found") }

    @Transactional  // overrides readOnly = true
    fun create(request: CreateOrderRequest): OrderResponse {
        val order = request.toEntity()
        return orderRepository.save(order).toResponse()
    }
}

// ❌ Never on controllers
@Transactional  // wrong place
@RestController
class OrderController(...)
```

**Rules:**
- Read methods: `readOnly = true` (improves performance, prevents accidental writes)
- Write methods: `@Transactional` (writable)
- Never start transactions in controllers
- Never call `@Transactional` methods from within the same bean (self-invocation bypasses the proxy)

---

## Optimistic Locking

Prevents lost updates in concurrent scenarios.

```kotlin
@Entity
class Product(
    @Id @GeneratedValue val id: Long = 0,
    var name: String,
    var stock: Int,

    @Version
    val version: Long = 0  // incremented by Hibernate on each update
)
```

```kotlin
// Catch optimistic lock failures in service
@Transactional
fun decreaseStock(productId: Long, quantity: Int) {
    val product = productRepository.findById(productId).orElseThrow()
    if (product.stock < quantity) throw InsufficientStockException()
    product.stock -= quantity
    // Hibernate throws OptimisticLockException if version changed since read
}
```

---

## Pagination

```kotlin
// Repository
interface UserRepository : JpaRepository<User, Long> {
    fun findByStatus(status: UserStatus, pageable: Pageable): Page<User>
}

// Service
fun getUsers(status: UserStatus, page: Int, size: Int): PagedResponse<UserResponse> {
    val pageable = PageRequest.of(page, size, Sort.by("name").ascending())
    val result = userRepository.findByStatus(status, pageable)
    return PagedResponse(
        content = result.content.map { it.toResponse() },
        totalElements = result.totalElements,
        totalPages = result.totalPages,
        number = result.number,
        size = result.size
    )
}
```

---

## Named Parameters — No String Concatenation

```kotlin
// ❌ Never build queries by string concatenation
@Query("SELECT u FROM User u WHERE u.status = '" + status + "'")

// ✅ Named parameter
@Query("SELECT u FROM User u WHERE u.status = :status AND u.role = :role")
fun findByStatusAndRole(
    @Param("status") status: UserStatus,
    @Param("role") role: Role
): List<User>

// ✅ Spring Data method name (no @Query needed for simple cases)
fun findByStatusAndRoleOrderByNameAsc(status: UserStatus, role: Role): List<User>
```

---

## DTO Projections (avoid loading full entities for reads)

```kotlin
// Interface projection — Spring Data generates the proxy
interface UserSummary {
    val id: Long
    val name: String
    val email: String
}

interface UserRepository : JpaRepository<User, Long> {
    fun findByStatus(status: UserStatus): List<UserSummary>  // returns projections, not entities
}

// Class projection (JPQL constructor expression)
data class UserSummary(val id: Long, val name: String)

@Query("SELECT new de.flxg.user.UserSummary(u.id, u.name) FROM User u WHERE u.status = :status")
fun findSummariesByStatus(@Param("status") status: UserStatus): List<UserSummary>
```

---

## Common Quick Reference

| Problem | Symptom | Solution |
|---|---|---|
| N+1 queries | Many SELECT per request | JOIN FETCH or @EntityGraph |
| LazyInitializationException | Error after transaction | DTO projection or JOIN FETCH |
| Lost update | Concurrent writes overwrite | `@Version` optimistic locking |
| Slow reads | Full entity loaded when summary needed | Interface/class projection |
| Accidental writes in read path | Dirty checking fires updates | `@Transactional(readOnly = true)` |
| Self-invocation | `@Transactional` ignored | Inject self or restructure |
