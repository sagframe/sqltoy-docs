# Database Migration Guide

This chapter targets **database migration** projects (migrating from Oracle, MySQL, etc. to DM, Kingbase, HighGo, Oscar, MogDB, Vastbase, GaussDB, OpenGauss and other databases). It organizes sqltoy's cross-database adaptation capabilities into an executable six-step checklist — assess → configure → refactor → verify → perform → cut over; each step links to the chapter holding the full mechanism and parameters. For the selection rationale and overall introduction, see `docs/multi-db-adaptation.en.md` in the source repository (linked from the README's "Documentation & Resources" table).

## 1. Assess First: Map the Adaptation Surface

1. **Classify SQL sources**: object operations (save/update/delete/load/updateFetch, etc.) have pagination, locking, merge and primary-key backfill generated per dialect by the framework — **no refactoring needed**; what actually needs assessment is custom sql (the three forms: xml configuration, `@Sql` annotations, and code sql — see [Dynamic SQL Specification](../query/dynamic_sql.md));
2. **Confirm target-database coverage**: see [Supported Databases](db_list.md) for the dialect list; for domestic databases without a dedicated dialect (especially PostgreSQL derivatives), first alias them onto the nearest dialect via `dialect` / `dialectMap`:

```properties
spring.sqltoy.dialectMap.kingbase=mysql
```

3. **Assess primary-key strategy**: `identity`/`sequence` carry dialect and case-sensitivity differences across databases; for a database migration prefer programmatic keys (22-digit/26-digit/snowflake/UUID) to eliminate this class of difference at the source — see [Primary Key Strategies](../primarykey/sqltoy_primarykey.md); existing sequence-based tables keep working, with backfill handled per dialect.

## 2. Configuration: Switch On Cross-DB Adaptation

```properties
# automatic cross-DB function adaptation (28 built-in functions)
spring.sqltoy.functionConverts=default
# reserved words used by the project; object operations and cross-DB SQL adapt automatically
spring.sqltoy.reservedWords=maxvalue,minvalue
# proxied databases / configured dialect differs from the real one (e.g. OceanBase configured as mysql): variant lookup follows the real dialect
spring.sqltoy.realDialectFirst=true
```

- Function adaptation covers the common differences: `nvl/ifnull/coalesce`, `to_char/date_format`, `decode`, `group_concat/listagg/string_agg`, `sysdate/now/current_timestamp`, `trunc/date_trunc`, `uuid`, `date_add`, etc.; forms that cannot be converted safely are kept **loud** (passed through for the target database to error on) and never silently rewritten — see [Dialect Self-Adaption & Function Extension](../dialect/sqltoy_function.md);
- The `<sql dialect="...">` attribute (solidify parsing in a declared dialect) and `realDialectFirst` (prefer the real dialect for variant lookup) are in sections 2.1 and 2.2 of the same chapter.

## 3. SQL Refactoring: Handle Each Difference Class Its Own Way

| Difference class | Typical symptom | Handling |
| --- | --- | --- |
| Function differences | `nvl`, `decode`, `to_char`, `sysdate`, `group_concat` | Adapted automatically by `functionConverts=default` — no manual work |
| Pseudo-tables | oracle family requires `from dual`; on pg/mysql/sqlserver writing it errors | Since 6.0.6 use the `@virtualTable()` macro — expanded or stripped per dialect at parse time |
| Structural differences | oracle `connect by` vs recursive CTE, database-specific hints, etc. | Dialect variants `sqlId_dialect` / `dialect_sqlId`; the framework picks by current database |
| Primary-key return case | PG-folding kernels are case-sensitive on `getGeneratedKeys` column hints | The framework lowercases the whole PG-folding family by default; overridable per dialect via `dialectReturnPrimaryColumnCase` |
| Create-table DDL | type and partition syntax differences | POJO annotations + quickvo generate DDL per database — see [POJO-to-DDL](../primarykey/sqltoy_ddl.md) |

Pseudo-table macro (expansion rules in [Dialect Self-Adaption & Function Extension](../dialect/sqltoy_function.md), section 3):

```sql
select '0' id,'Global' name @virtualTable()
union
select id,name from sys_tenant_info
```

Structural differences: attach dialect variants to the sqlId; business code calls only the base sqlId; lookup order is `dialect_sqlId → sqlId_dialect → sqlId`:

```xml
<!-- base version (recursive CTE): used on pg / mysql8+ / DM / Kingbase etc. -->
<sql id="dept_sub_tree">…recursive CTE…</sql>
<!-- automatically selected on oracle: connect by hierarchical query -->
<sql id="dept_sub_tree_oracle">…connect by…</sql>
```

## 4. Verification: Run Every Target Database Before Go-Live

```properties
spring.sqltoy.redoDataSources[0]=dmdb
spring.sqltoy.redoDataSources[1]=kingbasedb
```

Once configured, any query is **replayed once on those data sources** during testing, so incompatible constructs surface immediately instead of erroring at a customer site after the switch — see [Multi-DB Verification](../dialect/multi_db_verify.md). Two framework-level guarantees complement it:

- Pagination/locking/merge/sequence of every dialect are verified item by item against real databases, with reflection-based exhaustive assertions locking coverage completeness (adding a database type without registering its adaptation fails the test);
- The "loud retention" principle of function conversion means every error during verification is exactly an adaptation-surface item — there are no silent wrong values.

## 5. Performance: No Regression After Migration — Often a Gain

- **Pagination**: `findPage` enables smart count optimization by default (strips order by, trims select columns); for frequently paged scenarios add `<page-optimize parallel="true" alive-max="100" alive-seconds="120"/>` to cache the count and run it in parallel with the page query; for large-table join pagination use `@fast()` (paginate first, join afterwards) — see [Pagination](../query/pagination.md);
- **Cache translate**: code-to-name translation happens in memory, eliminating dictionary-table JOINs; supports incremental updates and FIFO caching for ultra-large master data — see [Cache Translate](../quickstart/translates.md);
- **High-concurrency ledgers**: `updateFetch` / `updateSaveFetch` complete lock-query → check → modify → return in a single database interaction — see [Objectified CRUD](../crud/sqltoy_crud.md);
- **Slow-SQL governance**: automatic slow-SQL identification and handling — see [Slow SQL](../enterprise/slow_sql.md); the SQL signature (`/*-id-*/`) makes database-log location a seconds-level task.

## 6. Cut-Over and Long-Term Operations

- During parallel running, combine with [Dynamic Datasources & Transactions](../config/dynamic_datasource.md) to cut over gradually per datasource;
- When a new domestic database appears, onboard it via a `dialectMap` alias first; once an official dialect lands, remove the alias to get native adaptation;
- Keep `redoDataSources` in the regression environment as a permanent gate for cross-DB adaptation.

## 7. Related Chapters

- [Supported Databases](db_list.md) · [Dialect Self-Adaption & Function Extension](../dialect/sqltoy_function.md) · [Multi-DB Verification](../dialect/multi_db_verify.md)
- [Pagination](../query/pagination.md) · [Cache Translate](../quickstart/translates.md) · [Primary Key Strategies](../primarykey/sqltoy_primarykey.md) · [POJO-to-DDL](../primarykey/sqltoy_ddl.md)
