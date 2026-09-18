# Platform Integration (Reporting / Low-Code Platforms)

sqltoy is built not only for regular application development (admin backends, microservice APIs, etc.) but also for **reporting platforms** and today's popular **low-code platforms** (a new development model where traditional feature pages and API services are built and deployed through page-based configuration).

Examples built on sqltoy:

- **sagacity-rainbow**: a rapid API development framework;
- **sagacity-nebula**: a reporting framework.

## 1. Integration Approach

The core idea is to hand the SQL xml fragments over to `SqlToyContext` for management. Reporting/low-code platforms dynamically produce or load SQL configurations at runtime, while sqltoy takes care of parsing, parameter binding, dialect adaptation and execution.

## 2. Parameter Binding: getFullParamNames

A common integration question is: **how do I bind the (report/page) condition parameters to the condition parameters inside the SQL?**

For reports, condition parameters are usually organized as a Map. `SqlToyConfig` provides the `getFullParamNames` method, which lets you obtain **all parameter names** in a SQL statement so that an external condition Map can be aligned with the SQL parameters:

```java
// Get all parameter names of the configuration for a given sqlId
SqlToyConfig config = lightDao.getSqlToyConfig("report_sql_id", SqlType.SELECT);
String[] paramNames = config.getFullParamNames();
// Use them to pick/assemble the actual parameters from the report's condition Map, then hand execution to sqltoy
```

## 3. Design Philosophy

> Sometimes a bit of flexibility goes a long way — just add an intermediate conversion step. As a foundational framework, sqltoy deliberately avoids flooding users with interfaces that would distract regular developers (offering "either this way or that way" only confuses them). Leave the dirty work — SQL hosting, parameter alignment, dialect adaptation — to the framework, and let the platform layer focus on business orchestration.

## 4. See Also

- For hands-on SQL-configuration-driven patterns (reports/API services), see [Common SQL Examples](../query/sql_showcase.md).
- For an overview of configuration parameters, see [sqltoy Configuration](../config/sqltoy_config.md).
