# SQL拦截加工、多租户过滤

## 介绍
随着 SaaS 化发展以及一些用户特殊的场景诉求，都需要对项目中的 SQL 做一些集中化的处理，如：
*   **租户过滤**：自动追加租户 ID 条件，防止数据越权。
*   **校验 SQL 注入**：增强安全性。
*   **修改 Schema**：根据需要替换实际的 Schema（例如 `select xxx from schema.table`）。

## 使用说明

### 1. 配置参数
通过配置 `spring.sqltoy.sqlInterceptors` 数组来注册拦截器。SQLToy 框架默认提供了 `TenantFilterInterceptor`，专门针对对象操作和 `findEntity` 等单表操作进行租户过滤。

**配置文件示例 (application.yml)：**

```yaml
spring:
  sqltoy:
    # 将 sqltoy 放于开始位置，避免很多开发者忽视了 spring.sqltoy 开头，变成了 sqltoy 开头导致无法加载
    sqltoy:
      # 多个路径用逗号分隔 (请务必看仔细)
      sqlResourcesDir: classpath:/sqltoy/quickstart
      # 默认为 classpath:sqltoy-translate.xml，一致则可以不用设置
      translateConfig: classpath:sqltoy-translate.xml
      # 针对 json 等特殊类型做处理 (可选配置)
      typeHandler: com.sqltoy.plugins.JsonTypeHandler
      # 可以填 default、defaultFormatter、defaultSqlFormatter 或者具体的类 (含包名)，sqltoy 提供的需要引入 druid jar
      sqlFormatter: defaultSqlFormatter
      
      # sql 拦截器，可以实现对 sql 的改写，比如多租户、sql 注入校验、改写的 schema 等
      sqlInterceptors:
        # 如果是具体的包路径和类名称，sqltoy 会自动实例化
        - org.sagacity.sqltoy.plugins.interceptors.TenantFilterInterceptor
        # 也可以注册一个 spring 的 bean，这里放入 bean 的名称
        # - yourInterceptorBeanName
```

### 2. 实体类标注
如果使用 SQLToy 自带的租户过滤，需在 POJO 上增加 `@Tenant` 注解，指定租户字段。

**实体类示例 (StaffInfoVO.java)：**

```java
/**
 * @project sqltoy-mssql
 * @author zhongxuchen
 * @version 1.0.0 Table: SQLTOY_STAFF_INFO
 */
// 指定租户字段为 tenantId
@Tenant(field = "tenantId")
@Entity(tableName = "SQLTOY_STAFF_INFO", comment = "", pk_constraint = "PK_SQLTOY_STAFF_INFO")
public class StaffInfoVO implements Serializable {
    // ... 字段定义
}
```

### 3. 拦截器逻辑与统一字段处理器
拦截器需要配合 **统一字段处理器 (`IUnifyFieldsHandler`)** 使用，以获取当前用户的授权租户信息。

#### A. 拦截器实现逻辑 (TenantFilterInterceptor.java)
框架会检查实体类是否包含租户字段，并获取授权租户信息进行过滤。

```java
public class TenantFilterInterceptor implements SqlInterceptor {

    @Override
    public SqlToyResult decorate(SqlToyContext sqlToyContext, SqlToyConfig sqlToyConfig, 
                                 SqlToyResult sqlToyResult, Class entityClass, Integer dbType) {
        // 存在统一字段处理、且是对象实体操作
        if (sqlToyContext.getUnifyFieldsHandler() == null || entityClass == null) {
            return sqlToyResult;
        }
        
        EntityMeta entityMeta = sqlToyContext.getEntityMeta(entityClass);
        
        // 不存在租户过滤控制
        if (entityMeta.getTenantField() == null) {
            return sqlToyResult;
        }
        
        // 【可选】你也可以用这种模式判断是否有租户字段，而非 @Tenant 注解模式
        // if (entityMeta.getColumnName("tenantId") != null) { ... }

        // 授权租户信息为空不做过滤
        // 通过统一字段处理器获取当前用户的授权租户
        String[] tenants = sqlToyContext.getUnifyFieldsHandler().authTenants(entityClass, OperateType.QUERY); // 假设是查询操作
        
        if (tenants == null || tenants.length == 0) {
            return sqlToyResult;
        }
        
        // ... 后续进行 SQL 改写，追加 and tenant_id in (...)
        return sqlToyResult;
    }
}
```

#### B. 统一字段处理器实现 (SqlToyUnifyFieldsHandler.java)
需实现 `IUnifyFieldsHandler` 接口，在 `authTenants` 方法中返回当前登录用户的租户 ID。

```java
/**
 * @project sqltoy-showcase
 * @description 统一字段赋值范例
 * @author chenrenfei
 * @version id:SqlToyUnifyFieldsHandler.java, Revision:v1.0, Date:2018年1月18日
 */
public class SqlToyUnifyFieldsHandler implements IUnifyFieldsHandler {
    
    private String defaultUserName = "system-auto";

    /**
     * 获取当前用户的授权租户信息，用于数据操作过程中进行统一的租户过滤，
     * 例如：update xxxx set xx=xx where id=? and tenant_id='S0002'
     */
    @Override
    public String[] authTenants(Class entityClass, OperateType operType) {
        // 注意这里是模拟参数，实际要通过当前用户信息中动态获取
        // 例如从 SecurityContext 或 ThreadLocal 中获取当前登录用户的租户ID
        return new String[] { "S0002" };
    }
}
```
