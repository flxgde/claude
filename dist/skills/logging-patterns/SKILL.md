---
name: logging-patterns
description: Structured JSON logging for Kotlin/Spring Boot — SLF4J setup, Logstash encoder, MDC correlation IDs, log levels, what not to log, and AI-friendly log formats. Use when adding logging, setting up observability, or debugging application flow.
---

# Logging Patterns for Kotlin/Spring Boot

## Logger Setup

```kotlin
// Option 1: Standard SLF4J (always available)
import org.slf4j.LoggerFactory

@Service
class OrderService(...) {
    private val log = LoggerFactory.getLogger(javaClass)
}

// Option 2: kotlin-logging (cleaner, lazy evaluation, recommended)
// implementation("io.github.oshai:kotlin-logging-jvm:6.x")
import io.github.oshai.kotlinlogging.KotlinLogging

private val log = KotlinLogging.logger {}

@Service
class OrderService(...) {
    fun create(request: CreateOrderRequest) {
        log.info { "Creating order for user ${request.userId}" }  // lazy — string only built if INFO enabled
    }
}
```

**Prefer kotlin-logging** — it uses lazy lambdas so string interpolation is not evaluated if the log level is disabled.

---

## Structured JSON Logging (Production)

Add the Logstash Logback encoder to `build.gradle.kts`:
```kotlin
implementation("net.logstash.logback:logstash-logback-encoder:7.x")
```

`src/main/resources/logback-spring.xml`:
```xml
<configuration>
    <springProfile name="!local">
        <!-- JSON for production / staging -->
        <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="net.logstash.logback.encoder.LogstashEncoder">
                <includeMdcKeyName>correlationId</includeMdcKeyName>
                <includeMdcKeyName>userId</includeMdcKeyName>
                <includeMdcKeyName>requestPath</includeMdcKeyName>
            </encoder>
        </appender>
        <root level="INFO">
            <appender-ref ref="JSON"/>
        </root>
    </springProfile>

    <springProfile name="local">
        <!-- Human-readable for local development -->
        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
            <encoder>
                <pattern>%d{HH:mm:ss} %-5level [%X{correlationId}] %logger{36} - %msg%n</pattern>
            </encoder>
        </appender>
        <root level="DEBUG">
            <appender-ref ref="CONSOLE"/>
        </root>
    </springProfile>
</configuration>
```

**Why JSON in production:**

| Aspect | Text | JSON |
|---|---|---|
| Log aggregation (ELK, Loki) | Regex parsing | Direct field query |
| AI/Claude analysis | Interpret strings | Direct field access |
| Filtering | `grep` patterns | `jq .level == "ERROR"` |
| Correlation | Parse manually | `jq 'select(.correlationId == "abc")` |

---

## MDC — Correlation IDs

Attach request-scoped context to every log line automatically.

```kotlin
// Spring Filter to set MDC on every request
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
class CorrelationIdFilter : OncePerRequestFilter() {

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        chain: FilterChain
    ) {
        val correlationId = request.getHeader("X-Correlation-Id")
            ?: UUID.randomUUID().toString()

        MDC.put("correlationId", correlationId)
        MDC.put("requestPath", request.requestURI)
        response.setHeader("X-Correlation-Id", correlationId)

        try {
            chain.doFilter(request, response)
        } finally {
            MDC.clear()
        }
    }
}
```

Now every log line from this request automatically includes `correlationId` and `requestPath` in the JSON output — no need to pass them around manually.

---

## Log Levels — What Goes Where

| Level | Use for |
|---|---|
| `ERROR` | Unexpected failures that need immediate attention (exceptions, data corruption) |
| `WARN` | Degraded state, retries, deprecated usage, approaching limits |
| `INFO` | Key business events: order created, user registered, payment processed |
| `DEBUG` | Detailed flow for troubleshooting (disabled in production by default) |
| `TRACE` | Very verbose: SQL queries, method entry/exit (development only) |

```kotlin
// ✅ Good log messages — structured, searchable
log.info { "Order created: orderId=$orderId userId=$userId total=$total" }
log.warn { "Payment retry: orderId=$orderId attempt=$attempt maxAttempts=$maxAttempts" }
log.error(e) { "Failed to process payment: orderId=$orderId" }

// ❌ Vague, unsearchable
log.info { "Order created" }
log.error { "Something went wrong" }
```

---

## What NOT to Log

```kotlin
// ❌ NEVER log passwords, tokens, secrets
log.debug { "Login attempt: user=$username password=$password" }     // NEVER
log.info { "Token generated: $jwtToken" }                            // NEVER

// ❌ NEVER log full PII unless legally required and consented
log.info { "User registered: name=$fullName ssn=$ssn iban=$iban" }  // NEVER

// ✅ Log identifiers only
log.info { "User registered: userId=$userId" }
log.info { "Login: userId=$userId success=true" }
```

---

## Logging Exceptions

```kotlin
// ✅ Always log the exception as the last parameter (enables stack trace in JSON)
try {
    processPayment(order)
} catch (e: PaymentException) {
    log.error(e) { "Payment failed: orderId=${order.id} reason=${e.message}" }
    throw e
}

// ❌ Losing the stack trace
log.error { "Payment failed: ${e.message}" }  // no stack trace
```

---

## application.yml — Log Level Configuration

```yaml
logging:
  level:
    root: INFO
    de.flxg: DEBUG          # your app — verbose in non-prod
    org.hibernate.SQL: DEBUG  # show SQL queries (development only)
    org.springframework.security: DEBUG  # auth flow debugging
    org.springframework.web: WARN
  pattern:
    console: "%d{HH:mm:ss} %-5level [%X{correlationId:-no-id}] %logger{36} - %msg%n"
```

---

## AI-Friendly Structured Events

For business events you want to analyze with AI tools or ship to monitoring:

```kotlin
// Structured event log — all fields are searchable
log.info {
    buildString {
        append("event=order_created ")
        append("orderId=$orderId ")
        append("userId=$userId ")
        append("itemCount=${items.size} ")
        append("total=$total ")
        append("currency=$currency")
    }
}

// In JSON output, each key=value pair becomes a field via the Logstash encoder's
// StructuredArguments support:
import net.logstash.logback.argument.StructuredArguments.kv

logger.info("Order created",
    kv("orderId", orderId),
    kv("userId", userId),
    kv("total", total)
)
```
