---
name: mongodb-patterns
description: MongoDB modeling and operational patterns — embed vs. reference, index design, aggregation pipeline structure, Spring Data MongoDB conventions, change streams, and transaction scope. Use when designing document schemas, writing aggregation pipelines, or configuring Spring Data MongoDB.
---

# MongoDB Patterns

Reference: https://www.mongodb.com/docs/manual/core/data-modeling-introduction/

## Embed vs. reference

- **Embed** when the sub-document is always read/written together with its parent, has a bounded
  size, and isn't queried independently — an order's line items, a user's address.
- **Reference** (store an `ObjectId` and look up separately) when the related data is large,
  unbounded (grows without limit — comments on a post), queried/updated independently of the
  parent, or shared across many parents.
- Don't default to embedding everything "because it's a document DB" — an unbounded embedded array
  (e.g. every order a customer ever placed, embedded in the customer document) hits the 16MB
  document size limit and makes the parent document expensive to load for an operation that only
  needed one field.

## Indexes

- Every query pattern you actually run needs a supporting index — check with `.explain("executionStats")`,
  not by assumption.
- Compound indexes: order fields by *equality* filters first, then *sort* fields, then *range*
  filters (the ESR rule) — the wrong order silently turns an indexed query into a collection scan
  for the range/sort portion.
- Don't create an index "just in case" — every index adds write-side cost and memory footprint;
  match indexes to real query patterns from the application code, not to every field that
  theoretically could be filtered on.

## Aggregation pipelines

- Put `$match` (and `$sort` when it can use an index) as early as possible in the pipeline — this
  lets Mongo use an index and avoids processing documents that get filtered out later anyway.
- Prefer `$project`/`$unset` early to shrink documents flowing through the rest of the pipeline
  when only a few fields are needed downstream.
- Use `$lookup` sparingly and only on indexed fields — it's the closest thing to a SQL join here,
  and unindexed lookups scan the target collection per input document.

## Spring Data MongoDB conventions

```java
public interface UserRepository extends MongoRepository<User, String> {
    Optional<User> findByEmail(String email);

    @Query("{ 'status': ?0 }")
    List<User> findAllByStatus(String status);
}
```

- Derive simple queries from method names; use `@Query` with placeholder args (`?0`, `?1`) for
  anything more complex than a single-field lookup.
- Annotate document classes with `@Document(collection = "...")` explicitly — don't rely on the
  default (pluralized, lowercased class name) once a project has more than a couple of collections.
- Use `@Indexed`/`@CompoundIndex` on the entity to keep index definitions next to the schema they
  apply to, rather than a separate untracked `createIndex` script.

## Change streams

Use a MongoDB change stream (via `ChangeStreamRequest`/`MessageListenerContainer` in Spring Data,
or the driver directly) when another service needs to react to writes on a collection in near
real-time — it's the MongoDB-native alternative to polling or dual-writing to a message queue.
Requires a replica set (even a single-node one for local dev) — a standalone `mongod` doesn't
support them.

## Transactions

Multi-document transactions exist and work (also require a replica set), but reach for them only
when a single logical operation truly must span multiple documents/collections atomically — the
more common MongoDB pattern is to design the schema so one write to one document *is* the atomic
unit, avoiding the need for a transaction and its performance cost.

## Spring Boot 4 note

See `spring-boot-engineer`'s own "Spring Boot 4 gotchas" section — connection properties moved from
`spring.data.mongodb.*` to `spring.mongodb.*` in Boot 4, and Boot **silently falls back to
defaults** if the old property names are still in use.
