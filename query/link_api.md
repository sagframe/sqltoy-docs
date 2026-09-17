# Link 链式操作

`LightDao` 除了提供 `save`/`update`/`find`/`findPage` 等显式接口外，还提供一组**链式（Link）入口**，把"设置参数 → 提交执行"组织成流畅的链式调用。当需要动态指定**数据源、锁、超时、批量大小、并行配置、强制更新字段**等时，链式写法更清晰灵活。

## 一、链式入口概览

| 入口 | 返回 | 用途 | 提交方法 |
| --- | --- | --- | --- |
| `lightDao.query()` | `Query` | SQL/实体查询 | `find()`/`getOne()`/`getValue()`/`count()`/`findPage()`/`findTop()`/`findRandom()` |
| `lightDao.save()` | `Save` | 保存对象 | `one(entity)`/`many(entities)` |
| `lightDao.update()` | `Update` | 修改对象 | `one(entity)`/`many(entities)` |
| `lightDao.delete()` | `Delete` | 删除对象 | `one(entity)`/`many(entities)` |
| `lightDao.load()` | `Load` | 加载对象（可级联/加锁） | `one(entity)`/`many(entities)` |
| `lightDao.unique()` | `Unique` | 唯一性校验 | `submit()` |
| `lightDao.execute()` | `Execute` | 执行 insert/update/delete SQL | `submit()`/`insertReturnPrimaryKey()` |
| `lightDao.batch()` | `Batch` | 批量执行 | `submit()` |
| `lightDao.store()` | `Store` | 存储过程调用 | `submit()` |
| `lightDao.treeTable()` | `TreeTable` | 树形表节点路径构造 | `submit()` |
| `lightDao.elastic()` | `Elastic` | Elasticsearch 查询 | `find()`/`getOne()`/`findPage()`/`findTop()` |
| `lightDao.mongo()` | `Mongo` | MongoDB 查询 | `find()`/`getOne()`/`findPage()`/`findTop()` |
| `lightDao.tableApi()` | `TableApi` | 表元数据/truncate/drop | 直接调用 |

> 几乎所有链式对象都支持 `.dataSource(DataSource)` 来**临时切换数据源**，以及 `.autoCommit(Boolean)`、`.batchSize(int)`、`.parallelConfig(ParallelConfig)` 等。

---

## 二、查询 query()

```java
// 查询列表：sql 可以是 xml 中的 sqlId，也可以是直接 sql
List<StaffInfoVO> list = lightDao.query()
        .sql("sys_staff_find")
        .names("staffName", "status")
        .values("张三", 1)
        .resultType(StaffInfoVO.class)
        .find();

// 通过对象传参（框架按 sql 中参数名映射对象属性取值）
StaffInfoVO one = (StaffInfoVO) lightDao.query()
        .sql("sys_staff_find")
        .entity(staffInfoVO)
        .resultType(StaffInfoVO.class)
        .getOne();

// 获取单值
Long count = lightDao.query().sql("select count(1) from sqltoy_staff_info").getValue(Long.class);

// 分页（Page 构造为 new Page(pageSize, pageNo)）
Page<StaffInfoVO> page = (Page) lightDao.query()
        .sql("sys_staff_find").resultType(StaffInfoVO.class)
        .findPage(new Page(10, 1));

// 取 Top / 随机
List top = lightDao.query().sql("sys_staff_find").resultType(StaffInfoVO.class).findTop(10);

// 加锁、超时、流式抓取大小
lightDao.query().sql(...).lock(LockMode.UPGRADE).queryTimeout(30).fetchSize(1000).find();
```

`Query` 可链式设置：`sql`、`names`、`values`、`entity`、`resultType`、`dataSource`、`fetchSize`、`maxRows`、`lock`、`lockWaitTimeout`、`queryTimeout`、`humpMapLabel`（Map 结果是否驼峰命名）。

---

## 三、保存 save()

```java
// 保存单个对象，返回主键
Object pk = lightDao.save().one(entity);

// 批量保存，返回成功条数
Long rows = lightDao.save().many(entities);

// 深度级联保存 + 保存模式 + 批量大小 + 并行
lightDao.save()
        .deeply(true)                 // 级联保存关联对象
        .saveMode(SaveMode.IGNORE)    // APPEND(普通)/UPDATE(saveOrUpdate)/IGNORE(存在则忽略)
        .batchSize(500)
        .parallelConfig(parallelConfig)
        .many(entities);
```

---

## 四、修改 update()

```java
// 弹性更新：默认 null 字段不参与更新，一次数据库交互完成
Long rows = lightDao.update().one(entity);

// 强制更新指定字段（即使值为 null 也更新）
lightDao.update().forceUpdateFields("photo", "remark").one(entity);

// 深度级联更新 / 指定级联类
lightDao.update().deeply(true).one(entity);
lightDao.update().cascadeClasses(OrganInfo.class).one(entity);

// 批量更新
lightDao.update().batchSize(500).many(entities);
```

`Update` 可链式设置：`deeply`、`updateFields`、`forceUpdateProps`、`forceUpdateFields`、`cascadeClasses`、`cascadeForceUpdate`、`batchSize`、`autoCommit`、`dataSource`、`parallelConfig`。

---

## 五、删除 delete() 与加载 load()

```java
// 删除
lightDao.delete().one(entity);
lightDao.delete().many(entities);

// 加载单个对象，并级联加载关联对象
StaffInfo staff = lightDao.load().cascade(OrganInfo.class).one(entity);
// 加载全部级联
lightDao.load().cascadeAll().one(entity);
// 加锁加载（悲观锁）
lightDao.load().lock(LockMode.UPGRADE).lockWaitTimeout(10).one(entity);
// 批量加载
List list = lightDao.load().many(entities);
```

`LockMode`：`UPGRADE`（普通悲观锁）、`UPGRADE_NOWAIT`（不等待）、`UPGRADE_SKIPLOCK`（跳过已锁记录）。

---

## 六、唯一性 unique()

```java
// 校验对象指定属性在数据库中是否唯一（属性名，非数据库列名）
boolean unique = lightDao.unique()
        .entity(entity)
        .fields("staffCode", "tenantId")
        .submit();
```

---

## 七、执行 SQL execute() 与批量 batch()

```java
// 执行 update/insert/delete/merge 等语句，返回影响行数
Long rows = lightDao.execute()
        .sql("update sqltoy_staff_info set status=:status where staff_id=:staffId")
        .names("status", "staffId").values(0, "S0001")
        .submit();

// insert 并返回主键
Object pk = lightDao.execute().sql("sys_staff_insert").entity(entity)
        .insertReturnPrimaryKey("staffId");

// 批量执行（dataSet 为 List<Map> 或 List<VO>）
Long batchRows = lightDao.batch()
        .sql("sys_staff_insert")
        .dataSet(dataList)
        .batchSize(500)
        .submit();
```

---

## 八、存储过程 store()

```java
// 调用存储过程并获取结果
StoreResult result = lightDao.store()
        .sql("{call storeName(?,?)}")
        .inParams(value1, value2)
        .resultType(StaffInfoVO.class)
        .submit();
List rows = result.getRows();

// 带 out 参数 / 多结果集
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

## 九、树形表 treeTable()

```java
// 构造树形表节点路径(node_route)、层级、叶子标识等
boolean ok = lightDao.treeTable()
        .treeModel(new TreeTableModel(OrganInfo.class)
                .idField("organId").pidField("organPid")
                .nodeRouteField("nodeRoute").nodeLevelField("nodeLevel")
                .isLeafField("leafField"))
        .submit();
```

---

## 十、NoSQL：elastic() 与 mongo()

```java
// Elasticsearch（sql 模式或原生 json 模式）
List list = lightDao.elastic().sql("es_sql_id").names(...).values(...).resultType(...).find();
Page page = lightDao.elastic().sql("es_sql_id").findPage(new Page(10, 1));

// MongoDB
List mList = lightDao.mongo().sql("mql_id").entity(queryVO).resultType(...).find();
```

详见 [Elasticsearch 支持](../nosql/sqltoy_elasticsearch.md) 与 [MongoDB 支持](../nosql/sqltoy_mongo.md)。

---

## 十一、表元数据 tableApi()

```java
// 获取表/列元数据
List<TableMeta> tables = lightDao.tableApi().getTables(null, null, "sqltoy%");
List<ColumnMeta> columns = lightDao.tableApi().getTableColumns(null, null, "sqltoy_staff_info");
// 清空表 / 删除表（支持表名或实体类）
lightDao.tableApi().truncate("sqltoy_staff_info");
lightDao.tableApi().drop(StaffInfo.class);
```
