# Multi-Tenancy

## Introduction
With the growth of SaaS adoption and some users' special scenario requirements, it often becomes necessary to centrally process the SQL in a project, for example:
*   **Tenant filtering**: automatically append the tenant ID condition to prevent data privilege escalation.
*   **SQL injection validation**: enhances security.
*   **Schema modification**: replace the actual schema as needed (e.g. `select xxx from schema.table`).

## Usage

### 1. Configuration Parameters
Register interceptors by configuring the `spring.sqltoy.sqlInterceptors` array. The SQLToy framework provides `TenantFilterInterceptor` out of the box, which performs tenant filtering specifically for object operations and single-table operations such as `findEntity`.

**Configuration file example (application.yml):**

```yaml
spring:
  sqltoy:
    # Keep sqltoy at the start, so developers do not overlook the spring.sqltoy prefix and write sqltoy instead, which would prevent loading
    sqltoy:
      # Separate multiple paths with commas (please read carefully)
      sqlResourcesDir: classpath:/sqltoy/quickstart
      # Defaults to classpath:sqltoy-translate.xml; no need to set it if identical
      translateConfig: classpath:sqltoy-translate.xml
      # Handles special types such as json (optional configuration)
      typeHandler: com.sqltoy.plugins.JsonTypeHandler
      # Can be default, defaultFormatter, defaultSqlFormatter, or a concrete class (with package name); the ones provided by sqltoy require the druid jar
      sqlFormatter: defaultSqlFormatter
      
      # SQL interceptors, which can rewrite SQL, e.g. multi-tenancy, SQL injection validation, schema rewriting, etc.
      sqlInterceptors:
        # If a concrete package path and class name is given, sqltoy will instantiate it automatically
        - org.sagacity.sqltoy.plugins.interceptors.TenantFilterInterceptor
        # You can also register a spring bean by putting the bean name here
        # - yourInterceptorBeanName
```

### 2. Entity Class Annotation
If you use SQLToy's built-in tenant filtering, you need to add the `@Tenant` annotation on the POJO to specify the tenant field.

**Entity class example (StaffInfoVO.java):**

```java
/**
 * @project sqltoy-mssql
 * @author zhongxuchen
 * @version 1.0.0 Table: SQLTOY_STAFF_INFO
 */
// Specify the tenant field as tenantId
@Tenant(field = "tenantId")
@Entity(tableName = "SQLTOY_STAFF_INFO", comment = "", pk_constraint = "PK_SQLTOY_STAFF_INFO")
public class StaffInfoVO implements Serializable {
    // ... field definitions
}
```

### 3. Interceptor Logic and the Unified Fields Handler
The interceptor must be used together with the **unified fields handler (`IUnifyFieldsHandler`)** to obtain the current user's authorized tenant information.

#### A. Interceptor Implementation Logic (TenantFilterInterceptor.java)
The framework checks whether the entity class contains a tenant field, then obtains the authorized tenant information to perform filtering.

```java
public class TenantFilterInterceptor implements SqlInterceptor {

    @Override
    public SqlToyResult decorate(SqlToyContext sqlToyContext, SqlToyConfig sqlToyConfig, 
                                 SqlToyResult sqlToyResult, Class entityClass, Integer dbType) {
        // A unified fields handler exists and the operation targets an entity object
        if (sqlToyContext.getUnifyFieldsHandler() == null || entityClass == null) {
            return sqlToyResult;
        }
        
        EntityMeta entityMeta = sqlToyContext.getEntityMeta(entityClass);
        
        // No tenant filtering configured
        if (entityMeta.getTenantField() == null) {
            return sqlToyResult;
        }
        
        // [Optional] You can also use this approach to check for a tenant field, instead of the @Tenant annotation
        // if (entityMeta.getColumnName("tenantId") != null) { ... }

        // Skip filtering when the authorized tenant information is empty
        // Get the current user's authorized tenants via the unified fields handler
        String[] tenants = sqlToyContext.getUnifyFieldsHandler().authTenants(entityClass, OperateType.QUERY); // assuming a query operation
        
        if (tenants == null || tenants.length == 0) {
            return sqlToyResult;
        }
        
        // ... then rewrite the SQL, appending and tenant_id in (...)
        return sqlToyResult;
    }
}
```

#### B. Unified Fields Handler Implementation (SqlToyUnifyFieldsHandler.java)
Implement the `IUnifyFieldsHandler` interface and return the current logged-in user's tenant IDs in the `authTenants` method.

```java
/**
 * @project sqltoy-showcase
 * @description unified fields assignment example
 * @author chenrenfei
 * @version id:SqlToyUnifyFieldsHandler.java, Revision:v1.0, Date:2018-01-18
 */
public class SqlToyUnifyFieldsHandler implements IUnifyFieldsHandler {
    
    private String defaultUserName = "system-auto";

    /**
     * Get the current user's authorized tenant information, used for unified tenant filtering
     * during data operations,
     * e.g.: update xxxx set xx=xx where id=? and tenant_id='S0002'
     */
    @Override
    public String[] authTenants(Class entityClass, OperateType operType) {
        // Note: this is a simulated value; in practice, obtain it dynamically from the current user's information
        // e.g. get the logged-in user's tenant ID from SecurityContext or ThreadLocal
        return new String[] { "S0002" };
    }
}
```
