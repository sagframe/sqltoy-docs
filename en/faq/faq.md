# FAQ

## 1. Why doesn't sharding support queries and pagination across multiple databases and tables?

The implementation itself is not hard; what's complex is the pagination merge after querying across multiple databases and tables. sqltoy deliberately skips this — **not because it can't be done, but because it isn't necessary** — such a requirement is essentially a design problem. The common practice today is to solve it with an MPP database such as ClickHouse or StarRocks, both of which sqltoy supports.

See [Sharding](../enterprise/sqltoy_sharding.md).

## 2. How is sqltoy-orm's performance?

Solving performance problems was one of sqltoy's original motivations:

- **Primary key strategies**: supports decentralized, application-generated modes (22-digit and 26-digit ordered nanosecond IDs, snowflake algorithm, etc.). Database lock-based modes were tried in the early days — a painful lesson.
- **update operations**: abandons hibernate's "load first, then update" model in favor of a **single database interaction** (elastic update).
- All SQL queries go through `PreparedStatement`, reducing the database's SQL precompilation overhead.
- Batch and cascading loads are based on batch queries, with data assembled in the background by the application, avoiding multiple database round trips (see the underlying implementation of `loadAllCascade`).
- Beyond fast pagination and pagination optimize, the count query is optimized to the extreme — not the naive `select count(1) from (your sql) as t`.

Most system bottlenecks lie in IO (especially database IO), and sqltoy heavily optimizes database interactions. The framework's own overhead for organizing and processing SQL statements is negligible — typically **under 1 millisecond**.

## 3. How are database reserved words handled?

Specify the `reservedWords` property in `sqltoyContext` to declare the reserved words your system uses.

- **Object-based operations**: sqltoy handles reserved word compatibility automatically.
- **Custom SQL**: you must handle specific fields per the current database yourself, e.g. reserved words in SQL Server need `[]`:

```sql
select [maxvalue],name from table
```

Across databases, sqltoy adapts the reserved words in custom SQL according to the defined `reservedWords`. For example, the SQL above automatically becomes the following in a MySQL project:

```sql
select `maxvalue`,name from table
```

> Note: it converts `[maxvalue]` into `` `maxvalue` ``, not bare `maxvalue` into `` `maxvalue` ``.

## 4. How do I set up multiple datasources?

For the complete dynamic-datasource configuration, `@DS` switching and `@DSTransactional` cross-database transaction examples, see [Multi-Datasource & Transactions](../config/dynamic_datasource.md).

sqltoy supports configuring a default datasource:

```properties
spring.sqltoy.defaultDataSource=primaryDB
```

Several implementation options:

1. **dynamic-datasource** (with transaction support): example https://gitee.com/sagacity/sqltoy-showcase/tree/master/trunk/sqltoy-dynamic-datasource
2. **Define multiple `LightDao` beans**, injecting a different dataSource into each, and wire them by bean name in the service layer.
3. **Query-level switching**: in the `QueryExecutor` of `findByQuery`/`findPageByQuery` etc. you can call `.dataSource(xxx)` directly; the chain API also supports `.dataSource(...)` (see [Link Chain API](../query/link_api.md)).
4. When **multi-database transactions** are involved, JTA can be used; see https://gitee.com/sagacity/sqltoy-showcase/tree/master/trunk/sqltoy-sharding

## 5. Can sqltoy be combined with other ORM frameworks?

Yes. You can use sqltoy standalone, or combine JPA with sqltoy queries, mixing them flexibly according to your situation.

## 6. How do I handle multi-column in conditions?

Use the tuple-in syntax directly, passing arrays/collections as parameters:

```sql
#[and (t.TECH_GROUP,t.PROD_GROUP) in (:techGroups,:prodGroups)]
```

When the in-condition parameter array exceeds 1000 entries (e.g. the Oracle limit), the framework (since 5.1.32 / 4.19.25) **splits it automatically**, so no manual handling is needed. You can also use `@secure-loop` to assemble complex conditions; see [Tags & Expressions Reference](../appendix/tags.md).

## 7. Can sqltoy be used outside Spring and Solon?

Yes. The core module `sagacity-sqltoy` can be used in pure Java: build `SqlToyContext` + a datasource + `DefaultLightDaoImpl` yourself, and use `DBTransUtils` for transactions. See [Pure Java Usage](../config/pure_java.md).
