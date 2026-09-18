# SQL查询功能


## lightDao API

### 前提：模板SQL

```xml
<sql id="sys_log_findlist">
	<!-- 分页优化器,通过缓存实现查询条件一致的情况下在一定时间周期内缓存总记录数量，从而无需每次查询总记录数量 -->
	<!-- parallel:是否并行查询总记录数和单页数据，当alive-max=1 时关闭缓存优化 -->
	<!-- alive-max:最大存放多少个不同查询条件的总记录量; alive-seconds:查询条件记录量存活时长(比如120秒,超过阀值则重新查询) -->
	<page-optimize parallel="true" alive-max="100" alive-seconds="120" />
	<value><![CDATA[
		select t1.*,t2.ORGAN_NAME 
		-- @fast() 实现先分页取10条(具体数量由pageSize确定),然后再关联
		from  @fast(
		      select t.*  from sqltoy_staff_info t
			   where t.STATUS=1 
			     #[and t.STAFF_NAME like :staffName] 
			   order by t.ENTRY_DATE desc 
			   ) t1 
		left join sqltoy_organ_info t2 on  t1.organ_id=t2.ORGAN_ID
          ]]>
	</value>
	<!-- 这里为极特殊情况下提供了自定义count-sql来实现极致性能优化 -->
	<!-- <count-sql></count-sql> -->
</sql>
```

#### findOne 查找单个记录

```java
SysLog sysLog = lightDao.findOne("sys_log_findlist", new SysLog(), SysLog.class);
```

#### find 查找列表

```java
List<SysLog> list = lightDao.find("sys_log_find_list", new SysLog(), SysLog.class);
```

#### findEntity 实体查询

```java
List<SysLog> list = lightDao.findEntity(SysLog.class, EntityQuery.create().names("operator").values("112233"));
```

#### findPage 分页查询

```java
Page<SysLog> page = lightDao.findPage(new Page<>(1, 10), "sys_log_find_list", new SysLog(), SysLog.class);
```

#### findPageEntity 分页实体查询

```java
Page<SysLog> page = lightDao.findPageEntity(new Page<>(1, 10), SysLog.class, EntityQuery.create().names("operator").values("112233"));
```

#### findTop 查找N条记录

```java
List<SysLog> list = lightDao.findTop("sys_log_find_list", new SysLog(), SysLog.class, 12);
```

#### findRandom 随机查找N条记录

```java
List<SysLog> list = lightDao.findRandom("sys_log_find_list", new SysLog(), SysLog.class, 12);
```

#### getValue、getCount、isUnique 快捷查询

* api

```java
// getValue：获取查询结果第一条、第一列的值（一般用于 select max(x)、统计值等）
public Object getValue(final String sqlOrSqlId, final Map<String, Object> paramsMap);
public <T> T getValue(final String sqlOrSqlId, final Map<String, Object> paramsMap, final Class<T> resultType);

// getCount：获取记录总量（sql 与单表实体查询两种形态）
public Long getCount(final String sqlOrSqlId, final Map<String, Object> paramsMap);
public Long getCount(Class entityClass, EntityQuery entityQuery);

// isUnique：校验对象属性值在表中是否唯一（常用于编码唯一性校验）
public boolean isUnique(Serializable entity, String... paramsNamed);
```

* 使用范例

```java
// 取统计值（指定返回类型）
BigDecimal maxAmt = lightDao.getValue("sqltoy_order_max_amt", paramsMap, BigDecimal.class);

// 记录总量
Long total = lightDao.getCount("sqltoy_order_find", paramsMap);
Long cnt = lightDao.getCount(StaffInfo.class, EntityQuery.create().where("status=?").values(1));

// 唯一性校验（返回 true 表示唯一；paramsNamed 为对象属性名，非数据库列名）
boolean unique = lightDao.isUnique(staffInfo, "staffCode");
// 链式写法：lightDao.unique().entity(entity).fields("staffCode").submit()，见 Link 链式操作
```

> 单条记录也可用 `loadByQuery(new QueryExecutor(sql).names(...).values(...)...)`（返回 Object）；常规场景建议直接用 `findOne`。
> Top / 随机查询也有 QueryExecutor 形态：`findTopByQuery(queryExecutor, topSize)` 与 `findRandomByQuery(queryExecutor, randomSize)`，详见上文 findTop / findRandom 章节。


#### fetchStream 流式数据获取

* 针对超大量数据，无法直接存放List等集合，提供反调方式由开发者自行将数据逐行写入到特定的文件或其他存储中

```java
/**
 * @TODO 流式获取查询结果
 * @param queryExecutor       可通过queryExecutor.showsql()开关sql输出日志
 * @param streamResultHandler
 */
//public void fetchStream(final QueryExecutor queryExecutor, final StreamResultHandler streamResultHandler);

List result = new ArrayList();
// sql 可以写在xml中，这里是演示
String sql = "select * from sqltoy_staff_info";
lightDao.fetchStream(new QueryExecutor(sql).resultType(StaffInfoVO.class),
    new StreamResultHandler() {
        @Override
        public void consume(Object row, int rowIndex) {
            result.add(row);
        }

        // end 一般用于写文件flush等
        @Override
        public void end() {
            System.err.println("完成执行");
        }
    }
);

for (Object item : result) {
    System.err.println(JSON.toJSONString(item));
}
```

> 🎬 完整可运行示例：演示项目 `sqltoy-showcase` 的 `FetchStreamTest.java`。

#### findByQuery 层次结构封装（主子表一次查询返回父子对象）

**场景**：主子表通过 join 一次性查出（如数据字典类型 + 字典明细），框架依据结果 VO 上的 `@OneToMany`/`@OneToOne` 注解，自动把平面结果集**分组分层封装**成父子对象（1..n 层级）——无需二次查询、无需手工组装。

**第一步：在结果 VO 上声明父子关系（`notNullField` 是关键）**

```java
/**
 * 主键关联子表信息
 * notNullField：封装层次结构时，以子表该字段值是否为 null 来辨别 join 出的记录子表是否有数据（左连接场景必设）
 */
@OneToMany(fields = { "dictType" }, mappedFields = { "dictType" }, delete = true,
        orderBy = "showIndex desc", notNullField = "dictKey")
private List<DictDetailVO> dictDetailVOs = new ArrayList<DictDetailVO>();
```

`@OneToMany` / `@OneToOne` 属性说明：

| 属性 | 说明 |
| --- | --- |
| `fields` | 主表关联列（可多个，对应复合主键） |
| `mappedFields` | 子表对象对应的关联属性 |
| `notNullField` | 层次封装时用于判断子表数据是否存在的非空字段（for hiberarchy） |
| `orderBy` | 级联加载/封装后的子表排序，如 `showIndex desc` |
| `load` | 自定义加载 sql（如 `enable=1` 或完整 sql：`select * from t where fkField=:fkField`） |
| `delete` | 是否级联删除 |
| `update` | 定制级联保存/修改时对子表的操作（`delete` 表示先删，`status=0` 表示置停用） |

**第二步：findByQuery + hiberarchy 完成分层封装**

```java
@Test
public void testOneToMany() {
    // 一条 join sql 同时查出字典主表 + 字典明细
    String sql = "select sdt.DICT_TYPE_NAME, sdt.COMMENTS dictTypeComments, "
            + "sdt.status dictTypeStatus, sdd.*, sdd.STATUS dictStatus from sqltoy_dict_type sdt "
            + " left join sqltoy_dict_detail sdd on sdt.DICT_TYPE = sdd.DICT_TYPE ";
    List<DictTypeVO> result = lightDao
            .findByQuery(new QueryExecutor(sql).resultType(DictTypeVO.class)
                    // 开启层次封装（若已设置 hiberarchyFieldsMap 则无需再设置）
                    .hiberarchy(true)
                    // 父子对象存在同名属性(如都有 status)时，将结果集 label 与对象属性对应：
                    // key 为查询结果的 label(别名)，value 为实际列/属性名
                    .hiberarchyFieldsMap(DictTypeVO.class,
                            MapKit.keys("dictTypeComments", "dictTypeStatus").values("COMMENTS", "status"))
                    .hiberarchyFieldsMap(DictDetailVO.class,
                            MapKit.keys("dictStatus").values("status")))
            .getRows();
    // 输出 JSON 即为 1..n 层级结构：每个字典类型下挂 dictDetailVOs 列表
    for (DictTypeVO dictType : result) {
        System.err.println(JSON.toJSONString(dictType));
    }
}
```

封装后的结果形如：

```json
{ "comments": "设备类型", "dictDetailVOs": [ { "dictKey": "NET", "dictName": "网络设备", "dictType": "DEVICE_TYPE", "showIndex": 2, "status": 1 } ] }
```

> [!NOTE]
> - 方法名是 `hiberarchy` / `hiberarchyFieldsMap`（框架历史拼写，不是 hierarchy）。
> - `hiberarchyFieldsMap` 会**自动开启**层次封装并登记涉及的类，因此设置了它就无需再调 `hiberarchy(true)`。
> - `hiberarchyFieldsMap` 只针对**父子对象存在同名属性**的场景；无同名属性时仅需 `hiberarchy(true)`。
> - 层次封装是"一条 join sql 直接打包"，与[对象化 CRUD](../crud/sqltoy_crud.md) 中的级联 load（按主键批量二次查询组装）是两种互补机制。

> 🎬 完整可运行示例：演示项目 `sqltoy-showcase` 的 `HierarchyPackagingTest.java`（其 `AbstractDictTypeVO` 的 @OneToMany 已配置 `notNullField = "dictKey"`）。

#### 存储过程调用

存储过程调用（`executeStore` / `executeMoreResultStore`、链式 `store()`、out 参数、**多结果集**）的完整说明与范例见 [存储过程调用](store_procedure.md)。

```java
// 快速示例：调用存储过程并获取结果集（无 out 参数时 outParamsType 传 null）
List result = lightDao.executeStore("{call storeName(?,?)}",
        new Object[]{ value1, value2 }, null, VO.class).getRows();
```
