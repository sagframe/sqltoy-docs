# Slow SQL Handling

sqltoy has a built-in mechanism for collecting and handling slow SQL (over-time SQL), making it easy to locate performance bottlenecks.

## 1. Default Configuration

The framework provides `DefaultOverTimeHandler` by default:

```properties
spring.sqltoy.overTimeSqlHandler=org.sagacity.sqltoy.plugins.overtime.DefaultOverTimeHandler
```

Together with the configuration parameter `printSqlTimeoutMillis` (8000 milliseconds by default), a warning log is printed when SQL execution exceeds that threshold.

## 2. Getting Slow SQL in Code

Get the slowest SQL statements through `SqlToyContext`:

```java
// Get the 10 slowest SQL statements (the second argument indicates whether to reset/clear the statistics)
List slowest = lightDao.getSqlToyContext().getSlowestSql(10, true);
```

## 3. Extending Slow SQL Collection

If you need custom collection logic (e.g. reporting to a monitoring system, writing to the database, integrating with an APM), implement the `OverTimeSqlHandler` interface yourself and configure:

```properties
spring.sqltoy.overTimeSqlHandler=com.yourpkg.YourOverTimeHandler
```

In the implementation class you get the over-time SQL statement, its parameters, its elapsed time and more, so you can persist it to the database, raise alerts or report it as needed.

> Related: for SQL execution statistics also refer to `org.sagacity.sqltoy.SqlExecuteStat`, `SqlExecuteTrace` and `SqlExecuteLog`. For common SQL optimization patterns see [SQL Showcase](../query/sql_showcase.md).
