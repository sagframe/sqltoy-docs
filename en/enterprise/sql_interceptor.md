# SQL Interceptors

With the rise of SaaS and various special-scenario requirements, it is often necessary to process the SQL in a project in a **centralized** way, for example: unified tenant filtering, SQL injection validation, schema rewriting (replacing the actual schema in `select xxx from schema.table` on demand), and so on. sqltoy implements this through the **SQL interceptor (SqlInterceptor)** mechanism, i.e. SQL interception & rewriting.

## 1. Configuration

Interceptors are registered via the configuration parameter `spring.sqltoy.sqlInterceptors` (an array); multiple interceptors can be configured:

```properties
spring.sqltoy.sqlInterceptors[0]=org.sagacity.sqltoy.plugins.interceptors.TenantFilterInterceptor
spring.sqltoy.sqlInterceptors[1]=com.yourpkg.YourSqlInterceptor
```

## 2. The SqlInterceptor Interface

A custom interceptor implements the `org.sagacity.sqltoy.plugins.SqlInterceptor` interface, whose core consists of two default methods:

```java
public interface SqlInterceptor {
    // Intercepts the SqlToyResult (final sql + parameters) before the SQL executes and returns the processed result
    default SqlToyResult decorate(SqlToyContext sqlToyContext, SqlToyConfig sqlToyConfig,
                                  OperateType operateType, String sql, Object[] params, ...) {
        return null;
    }
    // Returns the tenant field names of the entity (used for tenant filtering)
    default String[] tenantFieldNames(EntityMeta entityMeta, OperateType operateType) {
        return null;
    }
}
```

Inside `decorate` you get the SQL and parameters that are about to execute, so you can rewrite the SQL, append filter conditions, inject validation, replace the schema, and more.

## 3. Built-in Tenant Filter Interceptor

The framework provides `TenantFilterInterceptor` by default, which automatically appends tenant filter conditions for **object operations and single-table operations such as `findEntity`**. Using it requires:

1. **Adding the `@Tenant(field="xxx")` annotation to the POJO** (optional, marks the tenant field):

```java
@Tenant(field = "tenantId")
@Entity(tableName = "sqltoy_order_info")
public class OrderInfo implements Serializable {
    private String tenantId;
    // ...
}
```

2. **Providing the current user's authorized tenants via the unified fields handler (`IUnifyFieldsHandler`)**; based on this the interceptor decides whether the POJO contains a tenant field and appends the filtering.

Reference implementation: `org.sagacity.sqltoy.plugins.interceptors.TenantFilterInterceptor`.

> For the complete multi-tenancy configuration, including `@Tenant`, the unified fields handler and privilege-escalation filtering, see [Multi-Tenancy](sqltoy_multitenant.md) and [Data Permission & Overreach Check](sqltoy_permission.md).
