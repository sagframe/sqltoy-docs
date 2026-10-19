# Data Permission Passing and Overreach Check

In enterprise systems, "which organizations / account sets / tenants / business lines may the current user see" is information that **every query must carry but business code should not care about**. SqlToy splits this into two capabilities:

| Capability | Problem it solves | Implemented in |
| --- | --- | --- |
| **Unified parameter filling + overreach check** | Front end omitted it → fill in the authorized values; front end passed it → check for overreach and throw immediately | `IUnifyFieldsHandler.dataAuthFilters()` |
| **Automatic filtering by dimension** | The parameter should not even come from the front end: inject `tenant_id='x'` style conditions into the SQL | `SqlInterceptor` (built-in `TenantFilterInterceptor`) |

## 1. Unified parameter filling + overreach check (dataAuthFilters)

### 1.1 How it works

`IUnifyFieldsHandler.dataAuthFilters()` returns a **"SQL parameter name → authorization config"** map. Before every query/execution the framework inspects the **same-named parameters** in the SQL:

```java
public default IgnoreKeyCaseMap<String, DataAuthFilterConfig> dataAuthFilters() {
    return null;   // disabled by default
}
```

Behaviour, judged per named parameter:

| What the front end passed | What the framework does |
| --- | --- |
| Nothing (null/blank), or the `choiceAllValue` ("select all" marker) | **Fills the parameter with the authorized range `values`** (unified passing; business code does nothing) |
| A value, with `isForcelimit=true` | Compares every passed value against the authorized set; **any value outside it throws `DataAccessException`** |
| A value, with `isForcelimit=false` | No overreach check; the passed value is used as-is |

An overreach exception looks like this:

```text
param [organId] value [S004] is beyond the authorized scope
(see the implementation configured by spring.sqltoy.unifyFieldsHandler), please check!
```

### 1.2 DataAuthFilterConfig attributes

| Attribute | Notes |
| --- | --- |
| `values` | **The authorized values**: an array, collection or single value taken from the logged-in user's authorized scope (organ ids, account-set ids, tenant ids…) |
| `choiceAllValue` | The "select all" marker (e.g. a dropdown passing `-1`); when passed, it is treated as unspecified and `values` is used instead |
| `isForcelimit` | Whether to enforce the constraint (default `true`); `false` disables the overreach check |
| `ignoreType` | Whether to ignore type differences during comparison (e.g. the front end sends `String` while the authorized value is `BigInteger`) |

### 1.3 Example implementation

```java
@Component("unifyFieldsHandler")
public class SqlToyUnifyFieldsHandler implements IUnifyFieldsHandler {

    /** Current-user context (written into a ThreadLocal by a filter/interceptor) */
    @Override
    public IgnoreKeyCaseMap<String, DataAuthFilterConfig> dataAuthFilters() {
        IgnoreKeyCaseMap<String, DataAuthFilterConfig> map = new IgnoreKeyCaseMap<>();
        // (1) organization dimension: the :organId parameter in SQL
        map.put("organId", new DataAuthFilterConfig()
                .setValues(getAuthOrganIds())      // String[]: authorized organizations
                .setChoiceAllValue("-1")           // the "all" option passes -1, so use the authorized range
                .setForcelimit(true));             // overreach throws
        // (2) account-set dimension: authorized values are numeric, the front end sends strings
        map.put("accountSetId", new DataAuthFilterConfig()
                .setValues(getAuthAccountSetIds())
                .setIgnoreType(true));
        return map;
    }
}
```

Configuration (`unifyFieldsHandler` also fills common fields; this mechanism reuses the same implementation):

```properties
spring.sqltoy.unifyFieldsHandler=com.yourproject.SqlToyUnifyFieldsHandler
```

### 1.4 What the SQL looks like

Just make the parameter name match a key of `dataAuthFilters()` — no extra tags:

```xml
<sql id="staff_findlist">
    <value><![CDATA[
        select * from sqltoy_staff_info t
        where t.status=1
        #[and t.organ_id in (:organId)]
        #[and t.tenant_id=:tenantId]
    ]]></value>
</sql>
```

- Front end omits `organId` (or passes `-1`) → the framework fills in the authorized organizations;
- Front end passes `organId=S004` while only A/B/C are authorized → an overreach exception is thrown;
- Multiple values (arrays, or a comma string split by the `<split>` filter) are compared one by one.

### 1.5 Caveats

- **Parameter names must line up**: this is the classic trap — renaming the parameter in SQL without updating `dataAuthFilters()` silently disables the mechanism (an empty parameter just gets the authorized values, so it still "looks fine" while the overreach check never runs);
- **The authorized values must come from a trusted source**: `values` should be derived server-side from the login state, never from the front end;
- **Only SQL that actually has the named parameter is affected**: without the parameter in the SQL, no condition is invented (for "always filter" use the interceptor in section 2);
- **Paginated count caching**: `values` participates in the pagination count cache key, so a change of authorized scope naturally yields a different key and counts never leak across scopes;
- The single-table entity paths (`findEntity`/`updateByQuery`/`deleteByQuery`) behave exactly like non-entity queries.

## 2. Automatic filtering by dimension (TenantFilterInterceptor)

When the condition must be on **every** query and the front end never passes it, a SQL interceptor is more thorough: it injects the condition into the final SQL, so neither the business SQL nor its parameters mention that column.

### 2.1 Configuration

```properties
# built-in tenant/organization filtering interceptor
spring.sqltoy.sqlInterceptors[0]=org.sagacity.sqltoy.plugins.interceptors.TenantFilterInterceptor
# the interceptor takes the authorized values from the unified field handler
spring.sqltoy.unifyFieldsHandler=com.yourproject.SqlToyUnifyFieldsHandler
```

### 2.2 Where the authorized values come from

The interceptor asks `IUnifyFieldsHandler` for two values:

```java
/** The current user's authorized tenant/organization ids; operType distinguishes query/page/top/random/count etc. */
public default String[] authTenants(Class entityClass, OperateType operType) { ... }

/** Single-tenant simplification: return just the current user's tenant id */
public default String getUserTenantId() { ... }
```

`authTenants` wins; when it returns nothing, `getUserTenantId` is used. If both are empty, **no filtering happens** (fail-open — "not configured means not filtered", not "filter everything").

> For pagination, implement `authTenants`: the paginated count cache needs that value as part of its key, otherwise different tenants share one count.

### 2.3 Injection rules

- The tenant column comes from `@Tenant(field="...")` on the entity, or from the conventional column name (e.g. `tenantId`);
- It only applies to operations **that have an entity type** (object CRUD, `findEntity`, `findPageEntity`, `updateByQuery`, `deleteByQuery`, etc.); **a plain sqlId query has no entity and is not injected**;
- When the SQL already carries that tenant condition (`tenant_id=` / `tenant_id in` already present in the `where` part) it is **not injected twice**;
- SQL without a `where` gets the condition inserted before `group by`/`order by`;
- For `saveOrUpdate` (merge) it is injected into the `on` clause;
- Authorized values are spliced in as **literals** (single quotes are escaped by the framework), so they must come from a trusted source.

### 2.4 Relation to multi-tenancy

This mechanism is also one way to implement multi-tenant isolation: `@Tenant` + `TenantFilterInterceptor` filter and fill consistently. For the full multi-tenancy story (including filling the tenant column on write) see [Multi-Tenancy](sqltoy_multitenant.md).

## 3. Choosing between the two

| Scenario | Choice |
| --- | --- |
| The page has an organization/account-set filter the user may or may not set | `dataAuthFilters()` (unified filling + overreach check) |
| Isolation must always apply (SaaS tenant, hard data isolation) | `TenantFilterInterceptor` (automatic injection) |
| Isolation plus a **clear error** when the front end overreaches | `dataAuthFilters()` with `isForcelimit=true` |
| The filtering dimension is not an entity column (cross-table, complex expression) | A custom `SqlInterceptor`, see [SQL Interceptors](sql_interceptor.md) |

> The two can be combined: the interceptor provides the baseline isolation, `dataAuthFilters` handles filling the visible page condition and reporting overreach.

## 4. Related

- Full multi-tenancy usage: [Multi-Tenancy](sqltoy_multitenant.md)
- Custom SQL processing: [SQL Interceptors](sql_interceptor.md)
- The unified field handler interface (`createUnifyFields`/`updateUnifyFields`): [Common-Field Auto-Fill](../quickstart/helloworld_improve.md)
- All configuration properties: [Configuration](../config/sqltoy_config.md)
