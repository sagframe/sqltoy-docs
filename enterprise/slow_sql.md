# 慢 SQL 处理

sqltoy 内置慢 SQL（超时 SQL）收集与处理机制，便于定位性能瓶颈。

## 一、默认配置

框架默认提供 `DefaultOverTimeHandler`：

```properties
spring.sqltoy.overTimeSqlHandler=org.sagacity.sqltoy.plugins.overtime.DefaultOverTimeHandler
```

配合配置参数 `printSqlTimeoutMillis`（默认 8000 毫秒），当 SQL 执行超过该阈值时会输出告警日志。

## 二、代码中获取慢 SQL

通过 `SqlToyContext` 获取最慢的若干条 SQL：

```java
// 获取最慢的前 10 条 SQL（第二个参数表示是否重置/清空统计）
List slowest = lightDao.getSqlToyContext().getSlowestSql(10, true);
```

## 三、扩展慢 SQL 收集

如需自定义收集逻辑（如上报到监控系统、写入数据库、对接 APM），自行实现 `OverTimeSqlHandler` 接口，并配置：

```properties
spring.sqltoy.overTimeSqlHandler=com.yourpkg.YourOverTimeHandler
```

在实现类中可拿到超时 SQL 的语句、参数、耗时等信息，按需要落库、告警或上报。

> 相关：SQL 执行统计还可参考 `org.sagacity.sqltoy.SqlExecuteStat`、`SqlExecuteTrace`、`SqlExecuteLog`。常见 SQL 优化写法见[常见 SQL 案例](../query/sql_showcase.md)。
