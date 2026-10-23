# Configurable Service Foundation (Reports / Configurable API Services)

> `XMLBinding` and `parseSqlSegment` registration are available since sqltoy 6.0.x.

sqltoy's **sqlId + named-parameter** model is a natural fit for configuration-driven queries: SQL fragments are stored as `<sql>` **in a database (or a configuration center / report model)** and parsed and executed by the framework at runtime. This capability is exactly the foundation for page-configured reports, configurable API services, and low-code platforms — the development side only maintains "configuration", and services consume it by id without repeated releases.

## 1. Overall Idea

Configuration side: every SQL configuration carries a **unique id** and a **last-modified time** (used for cache invalidation).

Execution side: two styles, chosen by how often the configuration changes:

| Style | Use case | Notes |
| --- | --- | --- |
| `XMLBinding` dynamic execution | Queries whose configuration changes frequently | Every request passes id + lastUpdateTime; the framework decides whether the parse cache is hit by comparing timestamps, re-parsing only when something changed |
| `parseSqlSegment` + `putSqlToyConfig` registration | Relatively stable queries | Parse and register once at startup / on change; afterwards `lightDao.find(id, params)` behaves exactly like a static sqlId |

Dynamic columns: use `@joinFields(:fields, default)` to let configuration decide the `select` / `group by` / `order by` columns (field-name whitelist + dialect-aware reserved-word quoting), see [Tags & Expressions](en/appendix/tags.md).

## 2. Sample Configuration Storage (Database)

```sql
create table report_sql_config (
    report_id   varchar(64)  primary key,
    sql_xml     text         not null,   -- complete <sql>...</sql> fragment
    update_time datetime     not null
);
```

## 3. Style 1: Dynamic Execution via XMLBinding

```java
@Service
public class ReportService {

    @Autowired
    private LightDao lightDao;

    /** Load the SQL configuration fragment from DB / config center */
    private String loadSqlXml(String reportId) {
        // e.g. select sql_xml from report_sql_config where report_id = ?
        // or read from a config center / report model
        return lightDao.getValue("select sql_xml from report_sql_config where report_id = :reportId",
                MapKit.keys("reportId").values(reportId), String.class);
    }

    public List<Map> query(String reportId, LocalDateTime updateTime,
                           Map<String, Object> params) {
        String sqlXml = loadSqlXml(reportId);
        return lightDao.findByQuery(
                new QueryExecutor(new XMLBinding(sqlXml)
                        .id(reportId)
                        .lastUpdateTime(updateTime))  // hits the parse cache when unchanged
                .values(params)
                .resultType(Map.class))
            .getRows();
    }
}
```

**Cache rule (framework semantics):**

- Without `lastUpdateTime`: the first parse is cached and reused afterwards;
- With `lastUpdateTime`: re-parse when the cache is empty, or the time is newer than the cached one, or the cached model has no timestamp; otherwise hit the cache directly with no re-parse.

## 4. Style 2: Parse and Register, Reuse by sqlId

```java
public void registerReport(String reportId, String sqlXml) throws Exception {
    SqlToyConfig config = lightDao.getSqlToyContext().parseSqlSegment(sqlXml);
    // one report may contain several SQL fragments; use reportId + "_" + index to keep uniqueness
    config.setId(reportId);
    lightDao.getSqlToyContext().putSqlToyConfig(config);
}

public List<Map> queryById(String reportId, Map<String, Object> params) {
    // after registration this is identical to a static sqlId
    return lightDao.find(reportId, params);
}
```

> To unregister a no-longer-used id: `lightDao.getSqlToyContext().removeSql(reportId)`.

## 5. Dynamic Columns: Configuration Decides select / group by / order by

```xml
<sql id="report_dynamic_columns">
    <value><![CDATA[
        select @joinFields(:fields, t.order_id)
        from sqltoy_order_info t
        #[and t.trans_date >= :startDate]
        #[and t.trans_date < :endDate]
        order by @joinFields(:orderFields, t.trans_date)
    ]]></value>
</sql>
```

```java
List rows = lightDao.findByQuery(
        new QueryExecutor("report_dynamic_columns")
            .names("fields", "orderFields", "startDate", "endDate")
            .values(
                "t.order_id,t.customer_name,t.total_amt",  // plain identifiers, comma separated
                "t.total_amt,t.trans_date",
                "2026-01-01", "2026-01-31")
            .resultType(Map.class))
        .getRows();
```

**Notes:**

- `@joinFields` accepts **plain identifiers only** (field whitelist: letters including Chinese, digits, underscore, at most three dotted segments); expressions such as `sum(t.total_amt)` or `t.*` must keep using `@value` (security is on you).
- When a field name may hit a reserved word (`order` / `desc` / `level` / `group`, etc.), configure `spring.sqltoy.reservedWords` so the framework quotes it per dialect (backticks for mysql, double quotes for oracle/pg, square brackets for sqlserver).
- Sort direction is best fixed in the SQL text; if configuration must decide the direction, concatenate with `@value` and take responsibility for safety.

## 6. Integration with Report / Low-Code Platforms

- **One report, several SQL fragments**: parse and register each, uniquify with `reportId + "_" + index`, then fetch in order;
- **Stackable capabilities**: the configured fragment may use `<translate>` cache translation, `<summary>` / `<pivot>` / `<link>` in-memory analytics tags, etc. — no extra code;
- **Pagination**: `findPage` / `Page` behave exactly like a static sqlId.

## Related

- [Dynamic SQL Guide](en/query/dynamic_sql.md) (`#[]` dynamic segments, `@include`, `@joinFields` family)
- [Tags & Expressions](en/appendix/tags.md) (`@joinFields`, `@value`, `@loop` / `@secure-loop`, etc.)
- [Platform Integration (Reports / Low-Code)](en/tools/integration.md)
