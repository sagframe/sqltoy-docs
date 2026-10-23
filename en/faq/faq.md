# FAQ

## 1. Why doesn't sharding support queries and pagination across multiple databases and tables?

The implementation itself is not hard; what's complex is the pagination merge after querying across multiple databases and tables. sqltoy deliberately skips this — **not because it can't be done, but because it isn't necessary** — such a requirement is essentially a design problem. The common practice today is to solve it with an MPP database such as ClickHouse or StarRocks, both of which sqltoy supports.

See [Sharding](en/enterprise/sqltoy_sharding.md).

## 2. How is sqltoy-orm's performance?

Solving performance problems was one of sqltoy's original motivations:

- **Primary key strategies**: supports decentralized, application-generated modes (22-digit and 26-digit ordered nanosecond IDs, snowflake algorithm, etc.). Database lock-based modes were tried in the early days — a painful lesson.
- **update operations**: abandons hibernate's "load first, then update" model in favor of a **single database interaction** (elastic update).
- All SQL queries go through `PreparedStatement`, reducing the database's SQL precompilation overhead.
- Batch and cascading loads are based on batch queries, with data assembled in the background by the application, avoiding multiple database round trips (see the underlying implementation of `loadAllCascade`).
- Beyond fast pagination and pagination optimize, the count query is specifically optimized — not the naive `select count(1) from (your sql) as t`.

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

For the complete dynamic-datasource configuration, `@DS` switching and `@DSTransactional` cross-database transaction examples, see [Multi-Datasource & Transactions](en/config/dynamic_datasource.md).

sqltoy supports configuring a default datasource:

```properties
spring.sqltoy.defaultDataSource=primaryDB
```

Several implementation options:

1. **dynamic-datasource** (with transaction support): see [Multi-datasource & transactions](en/config/dynamic_datasource.md)
2. **Define multiple `LightDao` beans**, injecting a different dataSource into each, and wire them by bean name in the service layer.
3. **Query-level switching**: in the `QueryExecutor` of `findByQuery`/`findPageByQuery` etc. you can call `.dataSource(xxx)` directly; the chain API also supports `.dataSource(...)` (see [Link Chain API](en/query/link_api.md)).
4. When **multi-database transactions** are involved, JTA can be used (e.g. Atomikos/Narayana). For sqltoy's native named multi-datasource demo see `MultiDataSourceTest` in [sqltoy-showcase](https://gitee.com/sagacity/sqltoy-showcase).

## 5. Can sqltoy be combined with other ORM frameworks?

Yes. You can use sqltoy standalone, or combine JPA with sqltoy queries, mixing them flexibly according to your situation.

## 6. How do I handle multi-column in conditions?

Use the tuple-in syntax directly, passing arrays/collections as parameters:

```sql
#[and (t.TECH_GROUP,t.PROD_GROUP) in (:techGroups,:prodGroups)]
```

When the in-condition parameter array exceeds 1000 entries (e.g. the Oracle limit), the framework (since 5.1.32 / 4.19.25) **splits it automatically**, so no manual handling is needed. You can also use `@secure-loop` to assemble complex conditions; see [Tags & Expressions Reference](en/appendix/tags.md).

## 7. Can sqltoy be used outside Spring and Solon?

Yes. The core module `sagacity-sqltoy` can be used in pure Java: build `SqlToyContext` + a datasource + `DefaultLightDaoImpl` yourself, and use `DBTransUtils` for transactions. See [Pure Java Usage](en/config/pure_java.md).

## 8. Startup fails with a duplicate sqlId — or a later SQL overwrites an earlier one?

By default `breakWhenSqlRepeat=true`: a duplicate `sqlId` **throws and aborts startup**. That is deliberate — when the same SQL name exists in two files, production may well execute the wrong one.

Diagnosis:

```properties
# For temporary diagnosis only: false lets later definitions overwrite earlier ones (never ship this)
spring.sqltoy.breakWhenSqlRepeat=false
```

- Usual cause: two `*.sql.xml` files reuse one `id` after a module split, or an `@Sql` annotation id collides with an xml id;
- **Remember**: `sqlId` is a global namespace with no module prefix, so add a business prefix (e.g. `crm_staff_findlist`);
- If you really need the same name per datasource, use `<sql dataSource="...">` or dialect variants (`xxx_mysql`) rather than two same-named files.

See [Dynamic SQL Guide](en/query/dynamic_sql.md).

## 9. Cache translate does not work, or the page still shows old values

Work through these in order:

1. **Nothing was loaded**: `translateConfig` did not pick up your file (default `classpath:sqltoy-translate.xml;classpath:translates`); the startup log shows how many caches were loaded;
2. **Parameters do not line up**: the `columns` of `<translate columns="POST_TYPE" cache="dictCache">` must be **result-set column names**, not property names;
3. **Value types differ**: `1` (number) and `"1"` (string) do not match; normalize with the `to-string` filter;
4. **No incremental update**: by default the cache loads once and never changes; to follow the table configure `cache-update-checker` (timestamp/version based) or `rest-checker` (external endpoint);
5. **FIFO dynamic cache behaves as designed**: in `dynamic-cache` mode only keys **already present locally** are refreshed; a key that was never loaded naturally gets the new value on its next dynamic fetch — this is not a bug;
6. **Several instances**: local caches (ehcache/caffeine) are per-instance, so instances can disagree briefly inside a check interval; for strongly consistent code tables shorten the interval or use `rest-checker`.

See [Cache Translate](en/quickstart/translates.md) and [Large-Scale Cache (FIFO)](en/translate/sqltoy_FIFO_translate.md).

## 10. The count and the data disagree after using `@fast`

`@fast` means "**paginate the inner block to pageSize rows first, then join those rows to outer tables**", so its count **defaults to the inner @fast SQL** (the simplified form, skipping the join filters). If outer join conditions change the row count, the count no longer matches the data.

Options, in order:

1. **Push the filter into the @fast inner block** (anything the inner query can filter should not live in outer join conditions);
2. Provide the count explicitly with `<count-sql>` (`QueryExecutor.countSql(...)` works too) — the most controllable option;
3. Check for `union`: union counts have a dedicated union-all-count optimization (summing branches), and when combined with `@fast` the explicit `count-sql` wins.

See [Pagination Optimize](en/query/pagination.md).

## 11. Pagination returns nothing, or raises "maximum records per page exceeded"

Two safety mechanisms, both configurable:

| Parameter | Default | Behaviour |
| --- | --- | --- |
| `pageFetchSizeLimit` | 100000 | Maximum records per page; `pageNo=-1` (full extraction) trips it (`-1` disables the limit) |
| `overPageToFirst` | unset | Whether a page number beyond the last page returns to the first page; when unset the framework's built-in behaviour applies, so set it explicitly |

```properties
# Raise it only for a deliberate large-page export (watch memory)
spring.sqltoy.pageFetchSizeLimit=500000
# Send out-of-range page numbers back to the first page
spring.sqltoy.overPageToFirst=true
```

> For large exports prefer `fetchStream` (streaming callbacks) or batched `findTop` over pagination. See [Pagination Optimize](en/query/pagination.md).

## 12. Why does lambda's `getOne()` throw?

That is the **strict semantics** introduced in 6.0.8: 0 rows returns `null`, **more than one row throws `DataAccessException` (carrying the match count)**. The point is to stop a defective condition from being silently masked into "take the first row".

How to proceed:

- If the condition really should be unique, check for missing tenant/status conditions;
- If several rows are legitimate but you only want one, use `find()` and take the first, or add `orderBy` + `findTop(1)`;
- Likewise, **`update()/delete()` with no where condition throws by default**; use an explicit `.matchAll()` when a whole-table operation is truly intended.

See [Lambda Conditions](en/query/lambda_query.md).

## 13. Lambda conditions are unavailable in a native image, or startup reports missing reflection

Lambda relies on `SerializedLambda` and serialization mirroring to extract property names, so a closed-world native image must register them explicitly:

- **On the application side**, register by "lambda defining class" (Spring: `lambdaCapturingTypes` in `META-INF/native-image/**/serialization-config.json`, or `registerLambda(definingClass, b -> b.withInterfaces(LambdaFn.class))`; Solon: `registerLambdaSerialization(definingClass)`);
- Without registration the whole lambda system is unavailable under native (JVM mode is unaffected);
- Separately, **`updateSaveFetch` under native needs `native-entity-proxies`** to pre-generate the proxy, otherwise that branch is unavailable.

The complete checklist (entity scanning, DTO reflection, extension classes, function classes, JSON/vector/geometry driver classes) is in the [GraalVM Native Image Guide](en/tools/graalvm_native.md).

## 14. What must change when migrating from sqltoy-plus or MyBatis?

- **sqltoy-plus**: 6.0.8 folds the lambda capability into core. Drop the plugin dependency and `@EnableSqlToyPlus`, then follow the mapping table in [upgrade guide section 10.2](en/introduction/upgrade_6.0.md) for package/class renames, and regression-test the two behaviour changes (`getOne()` with multiple matches, unconditional update/delete);
- **MyBatis / MyBatis-Plus**: `<if>` → `#[]`, `QueryWrapper` → `EntityQuery` or lambda, `ResultMap` → result type/VO mapping, pagination plugin → `findPage`. The full mapping and rollout order are in [Migrating from MyBatis](en/introduction/migration.md).
