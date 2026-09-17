# SQL 拦截加工与多租户过滤

随着 SaaS 化以及一些特殊场景诉求，往往需要对项目中的 SQL 做**集中化处理**，如：统一租户过滤、校验 SQL 注入、修改 schema（`select xxx from schema.table` 按需替换实际 schema）等。sqltoy 通过 **SQL 拦截器（SqlInterceptor）** 机制实现。

## 一、配置

拦截器通过配置参数 `spring.sqltoy.sqlInterceptors`（数组）注册，可配置多个：

```properties
spring.sqltoy.sqlInterceptors[0]=org.sagacity.sqltoy.plugins.interceptors.TenantFilterInterceptor
spring.sqltoy.sqlInterceptors[1]=com.yourpkg.YourSqlInterceptor
```

## 二、SqlInterceptor 接口

自定义拦截器实现 `org.sagacity.sqltoy.plugins.SqlInterceptor` 接口，核心是两个默认方法：

```java
public interface SqlInterceptor {
    // 在 SQL 执行前对 SqlToyResult（最终 sql + 参数）进行加工，返回加工后的结果
    default SqlToyResult decorate(SqlToyContext sqlToyContext, SqlToyConfig sqlToyConfig,
                                  OperateType operateType, String sql, Object[] params, ...) {
        return null;
    }
    // 返回实体对象的租户字段名（用于租户过滤）
    default String[] tenantFieldNames(EntityMeta entityMeta, OperateType operateType) {
        return null;
    }
}
```

在 `decorate` 中即可拿到即将执行的 SQL 与参数，进行改写、追加过滤条件、注入校验、schema 替换等处理。

## 三、内置租户过滤拦截器

框架默认提供 `TenantFilterInterceptor`，针对**对象操作和 `findEntity` 等单表操作**自动追加租户过滤条件。使用它需要：

1. **POJO 上增加 `@Tenant(field="xxx")` 注解**（可选，标注租户字段）：

```java
@Tenant(field = "tenantId")
@Entity(tableName = "sqltoy_order_info")
public class OrderInfo implements Serializable {
    private String tenantId;
    // ...
}
```

2. **通过统一字段处理器（`IUnifyFieldsHandler`）提供当前用户的授权租户**，拦截器据此判断 POJO 中是否含租户字段并追加过滤。

参考实现：`org.sagacity.sqltoy.plugins.interceptors.TenantFilterInterceptor`。

> 多租户的完整配置与 `@Tenant`、统一字段处理器、越权过滤详见[多租户支持](sqltoy_multitenant.md)与[数据权限传参和越权校验](sqltoy_permission.md)。
