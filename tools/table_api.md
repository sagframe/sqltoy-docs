# 表元数据操作（TableApi）

`lightDao.tableApi()` 提供数据库表元数据查询与表级操作（truncate/drop），支持按表名或实体类操作，并可临时切换数据源。

## 一、API

```java
TableApi tableApi = lightDao.tableApi();

// 获取表信息（catalog/schema/tableName 支持通配，可传 null）
List<TableMeta> tables = tableApi.getTables(null, null, "sqltoy%");

// 获取表的列信息
List<ColumnMeta> columns = tableApi.getTableColumns(null, null, "sqltoy_staff_info");

// 清空表（支持表名或实体类）
tableApi.truncate("sqltoy_staff_info");
tableApi.truncate(StaffInfo.class);

// 删除表（支持表名或实体类）
tableApi.drop("sqltoy_staff_info");
tableApi.drop(StaffInfo.class);

// 临时切换数据源
tableApi.dataSource(otherDataSource).truncate("sqltoy_staff_info");
```

| 方法 | 说明 |
| --- | --- |
| `getTables(catalog, schema, tableName)` | 返回 `List<TableMeta>`，表名支持通配匹配 |
| `getTableColumns(catalog, schema, tableName)` | 返回 `List<ColumnMeta>`，含列名、类型、长度、注释等 |
| `truncate(Class entityClass)` / `truncate(String tableName)` | 清空表数据 |
| `drop(Class entityClass)` / `drop(String tableName)` | 删除表 |
| `dataSource(DataSource)` | 指定数据源 |

## 二、说明

- `LightDao` 上也直接提供了 `truncate(Class entityClass)` 快捷方法。
- `TableMeta` / `ColumnMeta` 封装了数据库元数据，可用于动态表单、代码生成、数据字典等场景。
- 不同数据库获取表信息的方式不同，有的需要通过 SQL 查询（如 Oracle 的 `select * from user_tab_comments`），此时直接用 sqltoy 的 SQL 查询即可；如需自行处理 `ResultSet`，可自定义 Dao 继承 `SpringDaoSupport`，使用 `DataSourceCallbackHandler` 反调模式。

> 由 POJO 反向生成建表 DDL 见 [POJO 生成表结构 DDL](../primarykey/sqltoy_ddl.md)。
