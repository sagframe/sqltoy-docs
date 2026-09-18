# Multi-DB Verification

Since the project was initiated in 2008, sqltoy has advocated **productization**: one software product adapting to multiple databases (e.g., a CRM that simultaneously supports Oracle, MySQL, DB2, SQL Server, PostgreSQL, DM (Dameng), GaussDB, etc.), making it easy to roll out across different customer scenarios. Only productization can build real competitiveness.

## 1. How to Make SQL Adapt to Multiple Databases

1. **Primary-key strategy**: minimize the use of `identity` and `sequence`, which are strongly database-dependent, and prefer sqltoy's programmatic primary keys (22-digit/26-digit/snowflake/UUID, etc., see [Primary Key Strategies](../primarykey/sqltoy_primarykey.md)).
2. **Inserts/updates/deletes**: use sqltoy's object-based operations (save/update/delete/load) and let the framework handle dialect differences.
3. **Queries**: enable `spring.sqltoy.functionConverts=default` so that functions in SQL are automatically adapted and replaced per database (see [Dialect Adaptation & Functions](sqltoy_function.md)).
4. When necessary, use `sqlId_dialect` / `dialect_sqlId` to provide dedicated SQL for specific databases.

## 2. Enable Cross-Database Adaptation Testing (redoDataSources)

To **also verify while testing that SQL runs correctly on other databases**, sqltoy provides the `redoDataSources` mechanism: after configuring the other types of databases the product needs to support, executing any query makes the framework **execute it once on the redoDataSources data sources at the same time**, thereby verifying the SQL's cross-database adaptability.

**Step 1: Configure multiple data sources with `@Configuration`** (focus on the two `@Bean` definitions for data sources), for example the primary database + a PostgreSQL database `pgdb`.

**Step 2: Configure the databases to be verified**

```properties
spring.sqltoy.redoDataSources[0]=pgdb
```

Once configured, whenever any query feature is executed, sqltoy replays (redo) that SQL once on `pgdb`. If the SQL contains incompatible dialect constructs, the replay exposes them immediately, so cross-database issues are discovered during development/testing instead of surfacing as errors only when the database is switched at a customer site.

> Tip: `redoDataSources` is for **adaptation verification** only; replayed queries do not affect the primary query result. It can be turned off in production.

## 3. Related

- Function auto-replacement and dialect sqlId: [Dialect Adaptation & Functions](sqltoy_function.md)
- Adapting unlisted PostgreSQL-family databases (dialect/dialectMap): [SQL Showcase](../query/sql_showcase.md)
