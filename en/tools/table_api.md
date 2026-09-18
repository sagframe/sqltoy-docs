# Table Metadata Operations (TableApi)

`lightDao.tableApi()` provides database table metadata queries and table-level operations (truncate/drop). It works with either table names or entity classes, and allows temporarily switching the data source.

## 1. API

```java
TableApi tableApi = lightDao.tableApi();

// Get table info (catalog/schema/tableName support wildcards and may be null)
List<TableMeta> tables = tableApi.getTables(null, null, "sqltoy%");

// Get a table's column info
List<ColumnMeta> columns = tableApi.getTableColumns(null, null, "sqltoy_staff_info");

// Truncate a table (by table name or entity class)
tableApi.truncate("sqltoy_staff_info");
tableApi.truncate(StaffInfo.class);

// Drop a table (by table name or entity class)
tableApi.drop("sqltoy_staff_info");
tableApi.drop(StaffInfo.class);

// Temporarily switch the data source
tableApi.dataSource(otherDataSource).truncate("sqltoy_staff_info");
```

| Method | Description |
| --- | --- |
| `getTables(catalog, schema, tableName)` | Returns `List<TableMeta>`; table names support wildcard matching |
| `getTableColumns(catalog, schema, tableName)` | Returns `List<ColumnMeta>`, including column name, type, length, comment, etc. |
| `truncate(Class entityClass)` / `truncate(String tableName)` | Truncates the table data |
| `drop(Class entityClass)` / `drop(String tableName)` | Drops the table |
| `dataSource(DataSource)` | Specifies the data source |

## 2. Notes

- `LightDao` also offers the shortcut `truncate(Class entityClass)` method directly.
- `TableMeta` / `ColumnMeta` wrap database metadata and can be used for dynamic forms, code generation, data dictionaries, and similar scenarios.
- Different databases expose table information differently; some require a SQL query (e.g. Oracle's `select * from user_tab_comments`). In that case simply use sqltoy's SQL query directly; if you need to process the `ResultSet` yourself, write a custom Dao extending `SpringDaoSupport` and use the `DataSourceCallbackHandler` callback pattern.

> To generate table DDL from POJOs, see [POJO to DDL](../primarykey/sqltoy_ddl.md).
