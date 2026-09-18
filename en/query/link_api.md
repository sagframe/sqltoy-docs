# Link Chain API

Besides explicit interfaces such as `save`/`update`/`find`/`findPage`, `LightDao` also provides a set of **fluent (Link) entry points** that organize "set parameters → submit and execute" into fluent chained calls. When you need to dynamically specify the **datasource, lock, timeout, batch size, parallel configuration, force-update fields**, etc., the fluent style is clearer and more flexible.

## 1. Fluent Entry Overview

| Entry | Returns | Purpose | Submit Methods |
| --- | --- | --- | --- |
| `lightDao.query()` | `Query` | SQL/entity query | `find()`/`getOne()`/`getValue()`/`count()`/`findPage()`/`findTop()`/`findRandom()` |
| `lightDao.save()` | `Save` | Save objects | `one(entity)`/`many(entities)` |
| `lightDao.update()` | `Update` | Update objects | `one(entity)`/`many(entities)` |
| `lightDao.delete()` | `Delete` | Delete objects | `one(entity)`/`many(entities)` |
| `lightDao.load()` | `Load` | Load objects (with cascade/lock) | `one(entity)`/`many(entities)` |
| `lightDao.unique()` | `Unique` | Uniqueness check | `submit()` |
| `lightDao.execute()` | `Execute` | Execute insert/update/delete SQL | `submit()`/`insertReturnPrimaryKey()` |
| `lightDao.batch()` | `Batch` | Batch execution | `submit()` |
| `lightDao.store()` | `Store` | Stored procedure call | `submit()` |
| `lightDao.treeTable()` | `TreeTable` | Tree-table node route building | `submit()` |
| `lightDao.elastic()` | `Elastic` | Elasticsearch query | `find()`/`getOne()`/`findPage()`/`findTop()` |
| `lightDao.mongo()` | `Mongo` | MongoDB query | `find()`/`getOne()`/`findPage()`/`findTop()` |
| `lightDao.tableApi()` | `TableApi` | Table metadata/truncate/drop | Direct call |

> Almost all fluent objects support `.dataSource(DataSource)` to **temporarily switch the datasource**, as well as `.autoCommit(Boolean)`, `.batchSize(int)`, `.parallelConfig(ParallelConfig)`, etc.

---

## 2. Query: query()

```java
// query a list: sql can be a sqlId defined in xml, or a direct sql
List<StaffInfoVO> list = lightDao.query()
        .sql("sys_staff_find")
        .names("staffName", "status")
        .values("Zhang San", 1)
        .resultType(StaffInfoVO.class)
        .find();

// pass parameters via an entity (the framework maps parameter names in the sql to entity properties to take values)
StaffInfoVO one = (StaffInfoVO) lightDao.query()
        .sql("sys_staff_find")
        .entity(staffInfoVO)
        .resultType(StaffInfoVO.class)
        .getOne();

// get a single value
Long count = lightDao.query().sql("select count(1) from sqltoy_staff_info").getValue(Long.class);

// pagination (Page is constructed as new Page(pageSize, pageNo))
Page<StaffInfoVO> page = (Page) lightDao.query()
        .sql("sys_staff_find").resultType(StaffInfoVO.class)
        .findPage(new Page(10, 1));

// top-N / random
List top = lightDao.query().sql("sys_staff_find").resultType(StaffInfoVO.class).findTop(10);

// lock, timeout, fetch size for stream fetching
lightDao.query().sql(...).lock(LockMode.UPGRADE).queryTimeout(30).fetchSize(1000).find();
```

`Query` supports fluent settings: `sql`, `names`, `values`, `entity`, `resultType`, `dataSource`, `fetchSize`, `maxRows`, `lock`, `lockWaitTimeout`, `queryTimeout`, `humpMapLabel` (whether Map result labels use camelCase).

---

## 3. Save: save()

```java
// save a single object and return the primary key
Object pk = lightDao.save().one(entity);

// batch save and return the number of successfully saved rows
Long rows = lightDao.save().many(entities);

// deep cascade save + save mode + batch size + parallel
lightDao.save()
        .deeply(true)                 // cascade save associated objects
        .saveMode(SaveMode.IGNORE)    // APPEND(normal)/UPDATE(saveOrUpdate)/IGNORE(ignore if exists)
        .batchSize(500)
        .parallelConfig(parallelConfig)
        .many(entities);
```

---

## 4. Update: update()

```java
// flexible update: by default null fields are excluded from the update, done in a single database interaction
Long rows = lightDao.update().one(entity);

// force update specific fields (updated even when the value is null)
lightDao.update().forceUpdateFields("photo", "remark").one(entity);

// deep cascade update / specify cascade classes
lightDao.update().deeply(true).one(entity);
lightDao.update().cascadeClasses(OrganInfo.class).one(entity);

// batch update
lightDao.update().batchSize(500).many(entities);
```

`Update` supports fluent settings: `deeply`, `updateFields`, `forceUpdateProps`, `forceUpdateFields`, `cascadeClasses`, `cascadeForceUpdate`, `batchSize`, `autoCommit`, `dataSource`, `parallelConfig`.

---

## 5. Delete: delete() and Load: load()

```java
// delete
lightDao.delete().one(entity);
lightDao.delete().many(entities);

// load a single object and cascade load associated objects
StaffInfo staff = lightDao.load().cascade(OrganInfo.class).one(entity);
// load all cascades
lightDao.load().cascadeAll().one(entity);
// locked load (pessimistic lock)
lightDao.load().lock(LockMode.UPGRADE).lockWaitTimeout(10).one(entity);
// batch load
List list = lightDao.load().many(entities);
```

`LockMode`: `UPGRADE` (normal pessimistic lock), `UPGRADE_NOWAIT` (no waiting), `UPGRADE_SKIPLOCK` (skip already-locked rows).

---

## 6. Uniqueness: unique()

```java
// check whether the entity's specified properties are unique in the database (property names, not database column names)
boolean unique = lightDao.unique()
        .entity(entity)
        .fields("staffCode", "tenantId")
        .submit();
```

---

## 7. Execute SQL: execute() and Batch: batch()

```java
// execute update/insert/delete/merge statements and return the affected row count
Long rows = lightDao.execute()
        .sql("update sqltoy_staff_info set status=:status where staff_id=:staffId")
        .names("status", "staffId").values(0, "S0001")
        .submit();

// insert and return the primary key
Object pk = lightDao.execute().sql("sys_staff_insert").entity(entity)
        .insertReturnPrimaryKey("staffId");

// batch execution (dataSet is List<Map> or List<VO>)
Long batchRows = lightDao.batch()
        .sql("sys_staff_insert")
        .dataSet(dataList)
        .batchSize(500)
        .submit();
```

---

## 8. Stored Procedure: store()

```java
// call a stored procedure and get the result
StoreResult result = lightDao.store()
        .sql("{call storeName(?,?)}")
        .inParams(value1, value2)
        .resultType(StaffInfoVO.class)
        .submit();
List rows = result.getRows();

// with out parameters / multiple result sets
StoreResult more = lightDao.store()
        .sql("{call storeName(?,?,?)}")
        .inParams(value1, value2)
        .outTypes(java.sql.Types.INTEGER)
        .moreResult(true)
        .resultTypes(StaffInfoVO.class)
        .submit();
Object[] outValues = more.getOutResult();
List[] allResults = more.getMoreResults();
```

---

## 9. Tree Table: treeTable()

```java
// build tree-table node route (node_route), node level, leaf flag, etc.
boolean ok = lightDao.treeTable()
        .treeModel(new TreeTableModel(OrganInfo.class)
                .idField("organId").pidField("organPid")
                .nodeRouteField("nodeRoute").nodeLevelField("nodeLevel")
                .isLeafField("leafField"))
        .submit();
```

---

## 10. NoSQL: elastic() and mongo()

```java
// Elasticsearch (sql mode or native json mode)
List list = lightDao.elastic().sql("es_sql_id").names(...).values(...).resultType(...).find();
Page page = lightDao.elastic().sql("es_sql_id").findPage(new Page(10, 1));

// MongoDB
List mList = lightDao.mongo().sql("mql_id").entity(queryVO).resultType(...).find();
```

See [Elasticsearch Support](../nosql/sqltoy_elasticsearch.md) and [MongoDB Support](../nosql/sqltoy_mongo.md) for details.

---

## 11. Table Metadata: tableApi()

```java
// get table/column metadata
List<TableMeta> tables = lightDao.tableApi().getTables(null, null, "sqltoy%");
List<ColumnMeta> columns = lightDao.tableApi().getTableColumns(null, null, "sqltoy_staff_info");
// truncate a table / drop a table (supports table names or entity classes)
lightDao.tableApi().truncate("sqltoy_staff_info");
lightDao.tableApi().drop(StaffInfo.class);
```
