# Release Notes (6.0 line)

The 6.0 line requires JDK 17+ (JDK 8 projects should stay on `5.6.96.jre8`). This page is an **index**: the full change list, caveats and upgrade actions for each release live in the matching chapter of the [6.0 Upgrade Guide](en/introduction/upgrade_6.0.md).

| Release | Highlights | Details |
| --- | --- | --- |
| **6.0.8** | **Lambda condition API moved into core** (`org.sagacity.sqltoy.lambda`: one builder for single-table and joins; the former sqltoy-plus capability is built in); **GraalVM AOT rewritten** (dynamic registration of resources, extension classes, JSON and driver classes; new `native-reflection-classes` / `native-reflection-packages` / `native-entity-proxies`; fixes the entity hints that had been empty since 5.6); dangling and/or inside brackets cleaned up after `#[...]` removal | [10. 6.0.8](en/introduction/upgrade_6.0.md) · [Lambda Conditions](en/query/lambda_query.md) · [GraalVM](en/tools/graalvm_native.md) |
| **6.0.7** | Pluggable JSON library (`JsonProvider`: fastjson2/jackson3/jackson2); new `@joinFields()` field-list joining macro; dangling and/or cleanup inside brackets | [9. 6.0.7](en/introduction/upgrade_6.0.md) · [Tags & Expressions](en/appendix/tags.md) |
| **6.0.6** | New virtual-table macro `@virtualTable()` (aliases `@dual()`/`@dummyTable()`) solving cross-database "constant rows union query" SQL; quickvo-maven-plugin 2.0.3 | [8. 6.0.6](en/introduction/upgrade_6.0.md) · [Dialect & Functions](en/dialect/sqltoy_function.md) |
| **6.0.5** | New HighGo dialect (24 → 25 dialects); 11 new cross-database function classes; inserted-key column names lowercased across the PG-folding family (OpenGauss/GaussDB/MogDB/Vastbase/StarDB/Oscar/Kingbase/HighGo) | [7. 6.0.5](en/introduction/upgrade_6.0.md) |
| **6.0.4** | Cache-translate REST authentication (basic/jwt with token-url login, local self-signing or a static token); function adaptation improvements (`nvl2`, negative-start `substr`, `curdate`, etc.); fixes for silently wrong values in negative-start SubStr and independent HH time tokens | [6. 6.0.4](en/introduction/upgrade_6.0.md) |
| **6.0.3** | `<sql dialect="xxx">` element attribute; `spring.sqltoy.realDialectFirst`; POJO-to-DDL enhancements (`@Partition`/`@PartitionDef`/`@MppTable`, dedicated Doris/StarRocks/ClickHouse/DB2/HANA/SQLite generators, `@Foreign` referential actions); sharding parallel-execution fixes | [5. 6.0.3](en/introduction/upgrade_6.0.md) · [POJO to DDL](en/primarykey/sqltoy_ddl.md) |
| **6.0.0** | JDK 17+; API renames `parallQuery`→`parallelQuery` (`ParallelQuery`) and `doConnection(conn, DBProfile)`; package reshuffle (`PageOptimizeUtils`/`ParallelUtils`/`TranslateUtils`, etc.); new SAP HANA dialect | [2. API changes](en/introduction/upgrade_6.0.md) · [3. Package changes](en/introduction/upgrade_6.0.md) |
| 5.6.96.jre8 | The final JDK 8 release (still supports quickvo-maven-plugin) | [Environment requirements](en/introduction/upgrade_6.0.md) |

## Finding what changed in a release

1. Locate the release here and follow "Details" into the matching chapter of the upgrade guide;
2. For **line-by-line detail** (root cause of each bug, databases verified, test cases) see `trunk/sqltoy-orm-core/changelog.md` in the source repository;
3. For the "do I need to change code?" answer: sections 2 (API changes) and 3 (package changes) of the upgrade guide — everything else is incremental.

## Choosing a version

| Scenario | Recommendation |
| --- | --- |
| New project | Use the latest 6.0.x |
| Existing 5.6.x on JDK 8 | Stay on `5.6.96.jre8`; do not upgrade your JDK just for the sake of it |
| Existing 5.6.x on JDK 17 | Walk through sections 1–11 of the [upgrade guide](en/introduction/upgrade_6.0.md), paying attention to the 6.0.0 API/package changes |
| Using sqltoy-plus | Upgrade to 6.0.8 and migrate to the built-in lambda API per [section 10.2](en/introduction/upgrade_6.0.md) |
| Building native images | 6.0.8+ and GraalVM 25+ |

> For older releases (5.x and earlier) consult the changelog in the source repository; this page only tracks the 6.0 line.
