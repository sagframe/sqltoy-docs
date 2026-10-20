# Multi-DB Verification

Since the project was initiated in 2008, sqltoy has advocated **productization**: one software product adapting to multiple databases (e.g., a CRM that simultaneously supports Oracle, MySQL, DB2, SQL Server, PostgreSQL, DM (Dameng), GaussDB, etc.), making it easy to roll out across different customer scenarios. Only productization can build real competitiveness.

## 1. How to Make SQL Adapt to Multiple Databases

1. **Primary-key strategy**: minimize the use of `identity` and `sequence`, which are strongly database-dependent, and prefer sqltoy's programmatic primary keys (22-digit/26-digit/snowflake/UUID, etc., see [Primary Key Strategies](../primarykey/sqltoy_primarykey.md)).
2. **Inserts/updates/deletes**: use sqltoy's object-based operations (save/update/delete/load) and let the framework handle dialect differences.
3. **Queries**: enable `spring.sqltoy.functionConverts=default` so that functions in SQL are automatically adapted and replaced per database (see [Dialect Adaptation & Functions](sqltoy_function.md)).
4. **Constant-row pseudo-tables**: for "select constant-row union real-query" SQL (dictionary dropdown fallback rows, fixed report total rows, etc.), use the virtual-table macro `@virtualTable()` (new in 6.0.6) — expanded at parse time per dialect into `from dual` / `from sysibm.sysdummy1` / `from dummy`, or simply stripped, so you no longer maintain per-database `from dual` forms; see [Dialect Adaptation & Functions](sqltoy_function.md).
5. When necessary, use `sqlId_dialect` / `dialect_sqlId` to provide dedicated SQL for specific databases; since 6.0.3 you can also declare a `dialect` attribute on the `<sql>` element to solidify parsing in a specified dialect, and enable `spring.sqltoy.realDialectFirst` so variant lookup prefers the real dialect detected from the connection — see [Dialect Adaptation & Functions](sqltoy_function.md).

## 2. Enable Cross-Database Adaptation Testing (redoDataSources)

To **also verify while testing that SQL runs correctly on other databases**, sqltoy provides the `redoDataSources` mechanism: after configuring the other types of databases the product needs to support, executing any query makes the framework **execute it once on the redoDataSources data sources at the same time**, thereby verifying the SQL's cross-database adaptability.

**Step 1: Configure multiple data sources with `@Configuration`** (focus on the two `@Bean` definitions for data sources), for example the primary database + a PostgreSQL database `pgdb`.

**Step 2: Configure the databases to be verified**

```properties
spring.sqltoy.redoDataSources[0]=pgdb
```

Once configured, whenever any query feature is executed, sqltoy replays (redo) that SQL once on `pgdb`. If the SQL contains incompatible dialect constructs, the replay exposes them immediately, so cross-database issues are discovered during development/testing instead of surfacing as errors only when the database is switched at a customer site.

> Tip: `redoDataSources` is for **adaptation verification** only; replayed queries do not affect the primary query result. It can be turned off in production.

## 3. Supporting Tools and Verification Projects

| Tool | Purpose |
| --- | --- |
| [sagacity-db-diversity](https://github.com/sagframe/sagacity-db-diversity) | **Schema difference comparison**: connect to a reference database and a target database separately, export tables/columns/primary keys/foreign keys/indexes/comments to xml, then compare offline. It supports one-sided connections (a dev environment reachable only through a bastion) and comparing exports taken at different times. Run it before a database migration and clear the schema differences first |
| [sqltoy-aot-verify](https://github.com/sagframe/sqltoy-aot-verify) | **Native-build verification matrix** (Spring + Solon, PostgreSQL pgvector + postgis) that also covers dialect function conversion and both cache-translate implementations |
| [sqltoy-showcase](https://gitee.com/sagacity/sqltoy-showcase) | Full-feature demo project (two H2 databases simulating a sharded topology + real Mongo/ES via Testcontainers); for **per-database verification** see Lesson 9 of [sqltoy-quickstart](https://github.com/sagframe/sqltoy-quickstart): the same function-conversion SQL run against dockerized PostgreSQL / SQL Server / Oracle / MySQL |

Caveats for `redoDataSources`:

- Only **queries** are replayed; writes are not. Use it in development/testing and switch it off in production;
- Every query hits the database one extra time, so **test-environment latency and connection usage roughly double** — do not enable it during load tests;
- It exposes **dialect incompatibilities**, and is no substitute for business result validation (the same SQL can differ subtly per database: case sensitivity, ordering, null ordering).

## 4. Related

- Function auto-replacement and dialect sqlId: [Dialect Adaptation & Functions](sqltoy_function.md)
- Adapting unlisted PostgreSQL-family databases (dialect/dialectMap): [SQL Showcase](../query/sql_showcase.md)
- The full migration assessment checklist: [Database Migration Guide](../introduction/xinchuang.md)
