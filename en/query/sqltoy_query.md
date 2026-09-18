# Query API


## lightDao API

### Prerequisite: Template SQL

```xml
<sql id="sys_log_findlist">
	<!-- Pagination optimizer: when the query conditions stay identical, caches the total record count for a period of time so the total count does not need to be queried on every request -->
	<!-- parallel: whether to query the total record count and the single page of data in parallel; cache optimization is disabled when alive-max=1 -->
	<!-- alive-max: how many counts for different query conditions can be kept at most; alive-seconds: how long a query-condition count stays alive (e.g. 120 seconds; beyond the threshold it is queried again) -->
	<page-optimize parallel="true" alive-max="100" alive-seconds="120" />
	<value><![CDATA[
		select t1.*,t2.ORGAN_NAME 
		-- @fast() paginates first and takes 10 rows (the exact number is determined by pageSize), then joins
		from  @fast(
		      select t.*  from sqltoy_staff_info t
			   where t.STATUS=1 
			     #[and t.STAFF_NAME like :staffName] 
			   order by t.ENTRY_DATE desc 
			   ) t1 
		left join sqltoy_organ_info t2 on  t1.organ_id=t2.ORGAN_ID
          ]]>
	</value>
	<!-- For extremely special cases, a custom count-sql is provided here to achieve ultimate performance optimization -->
	<!-- <count-sql></count-sql> -->
</sql>
```

#### findOne: Find a Single Record

```java
SysLog sysLog = lightDao.findOne("sys_log_findlist", new SysLog(), SysLog.class);
```

#### find: Find a List

```java
List<SysLog> list = lightDao.find("sys_log_find_list", new SysLog(), SysLog.class);
```

#### findEntity: Entity Query

```java
List<SysLog> list = lightDao.findEntity(SysLog.class, EntityQuery.create().names("operator").values("112233"));
```

#### findPage: Paginated Query

```java
Page<SysLog> page = lightDao.findPage(new Page<>(1, 10), "sys_log_find_list", new SysLog(), SysLog.class);
```

#### findPageEntity: Paginated Entity Query

```java
Page<SysLog> page = lightDao.findPageEntity(new Page<>(1, 10), SysLog.class, EntityQuery.create().names("operator").values("112233"));
```

#### findTop: Find Top-N Records

```java
List<SysLog> list = lightDao.findTop("sys_log_find_list", new SysLog(), SysLog.class, 12);
```

#### findRandom: Find N Random Records

```java
List<SysLog> list = lightDao.findRandom("sys_log_find_list", new SysLog(), SysLog.class, 12);
```

#### getValue, getCount, isUnique: Shortcut Queries

* api

```java
// getValue: returns the value of the first row and first column of the query result (typically used for select max(x), aggregate values, etc.)
public Object getValue(final String sqlOrSqlId, final Map<String, Object> paramsMap);
public <T> T getValue(final String sqlOrSqlId, final Map<String, Object> paramsMap, final Class<T> resultType);

// getCount: returns the total record count (available for both SQL and single-table entity query forms)
public Long getCount(final String sqlOrSqlId, final Map<String, Object> paramsMap);
public Long getCount(Class entityClass, EntityQuery entityQuery);

// isUnique: checks whether the entity's property values are unique in the table (commonly used for uniqueness validation of codes)
public boolean isUnique(Serializable entity, String... paramsNamed);
```

* usage examples

```java
// get an aggregate value (with an explicit return type)
BigDecimal maxAmt = lightDao.getValue("sqltoy_order_max_amt", paramsMap, BigDecimal.class);

// total record count
Long total = lightDao.getCount("sqltoy_order_find", paramsMap);
Long cnt = lightDao.getCount(StaffInfo.class, EntityQuery.create().where("status=?").values(1));

// uniqueness check (returns true when unique; paramsNamed takes entity property names, not database column names)
boolean unique = lightDao.isUnique(staffInfo, "staffCode");
// fluent form: lightDao.unique().entity(entity).fields("staffCode").submit(), see Link Chain API
```

> A single record can also be fetched with `loadByQuery(new QueryExecutor(sql).names(...).values(...)...)` (returns Object); for common scenarios `findOne` is recommended.
> Top / random queries also have QueryExecutor forms: `findTopByQuery(queryExecutor, topSize)` and `findRandomByQuery(queryExecutor, randomSize)`, see the findTop / findRandom sections above.


#### fetchStream: Stream Data Fetching

* For extremely large data volumes that cannot be held directly in a List or other collection, a callback approach is provided so developers can write the data row by row into a specific file or other storage themselves

```java
/**
 * @TODO fetch query results as a stream
 * @param queryExecutor       use queryExecutor.showsql() to toggle SQL log output
 * @param streamResultHandler
 */
//public void fetchStream(final QueryExecutor queryExecutor, final StreamResultHandler streamResultHandler);

List result = new ArrayList();
// the sql can be defined in xml; here it is shown inline for demonstration
String sql = "select * from sqltoy_staff_info";
lightDao.fetchStream(new QueryExecutor(sql).resultType(StaffInfoVO.class),
    new StreamResultHandler() {
        @Override
        public void consume(Object row, int rowIndex) {
            result.add(row);
        }

        // end is typically used for flushing files, etc.
        @Override
        public void end() {
            System.err.println("Execution completed");
        }
    }
);

for (Object item : result) {
    System.err.println(JSON.toJSONString(item));
}
```

> 🎬 Full runnable example: `FetchStreamTest.java` in the demo project `sqltoy-showcase`.

#### findByQuery: Hierarchy Packaging (parent and child objects returned in one query)

**Scenario**: the parent-child tables are fetched in a single join (e.g. data dictionary types + dictionary details), and based on the `@OneToMany`/`@OneToOne` annotations on the result VO, the framework automatically **groups and packages the flat result set** into parent-child objects (1..n levels) — no second query, no manual assembly.

**Step 1: declare the parent-child relationship on the result VO (`notNullField` is the key)**

```java
/**
 * child table info associated by primary key
 * notNullField: when packaging the hierarchy, whether this child-table field is null decides whether the joined record has child-table data (must be set for left-join scenarios)
 */
@OneToMany(fields = { "dictType" }, mappedFields = { "dictType" }, delete = true,
        orderBy = "showIndex desc", notNullField = "dictKey")
private List<DictDetailVO> dictDetailVOs = new ArrayList<DictDetailVO>();
```

`@OneToMany` / `@OneToOne` attributes:

| Attribute | Description |
| --- | --- |
| `fields` | Parent-table association columns (multiple allowed, corresponding to composite keys) |
| `mappedFields` | Corresponding association properties on the child object |
| `notNullField` | Non-null field used to decide whether child-table data exists during hierarchy packaging (for hiberarchy) |
| `orderBy` | Child-table ordering after cascade load/packaging, e.g. `showIndex desc` |
| `load` | Custom load sql (e.g. `enable=1` or a full sql: `select * from t where fkField=:fkField`) |
| `delete` | Whether to cascade delete |
| `update` | Custom operation on the child table during cascade save/update (`delete` means delete first, `status=0` means disable) |

**Step 2: findByQuery + hiberarchy packages the hierarchy**

```java
@Test
public void testOneToMany() {
    // one join sql fetches the dictionary parent table and the dictionary details together
    String sql = "select sdt.DICT_TYPE_NAME, sdt.COMMENTS dictTypeComments, "
            + "sdt.status dictTypeStatus, sdd.*, sdd.STATUS dictStatus from sqltoy_dict_type sdt "
            + " left join sqltoy_dict_detail sdd on sdt.DICT_TYPE = sdd.DICT_TYPE ";
    List<DictTypeVO> result = lightDao
            .findByQuery(new QueryExecutor(sql).resultType(DictTypeVO.class)
                    // enable hierarchy packaging (not needed if hiberarchyFieldsMap is already set)
                    .hiberarchy(true)
                    // when parent and child objects have same-named properties (e.g. both have status), map result-set labels to object properties:
                    // key is the query result's label (alias), value is the actual column/property name
                    .hiberarchyFieldsMap(DictTypeVO.class,
                            MapKit.keys("dictTypeComments", "dictTypeStatus").values("COMMENTS", "status"))
                    .hiberarchyFieldsMap(DictDetailVO.class,
                            MapKit.keys("dictStatus").values("status")))
            .getRows();
    // the JSON output is a 1..n hierarchy: each dictionary type carries a dictDetailVOs list
    for (DictTypeVO dictType : result) {
        System.err.println(JSON.toJSONString(dictType));
    }
}
```

The packaged result looks like:

```json
{ "comments": "Device Type", "dictDetailVOs": [ { "dictKey": "NET", "dictName": "Network Device", "dictType": "DEVICE_TYPE", "showIndex": 2, "status": 1 } ] }
```

> [!NOTE]
> - The method names are `hiberarchy` / `hiberarchyFieldsMap` (a historical spelling in the framework, not hierarchy).
> - `hiberarchyFieldsMap` **automatically enables** hierarchy packaging and registers the involved classes, so once it is set there is no need to call `hiberarchy(true)` again.
> - `hiberarchyFieldsMap` only targets the scenario where **parent and child objects have same-named properties**; without name conflicts, `hiberarchy(true)` alone is enough.
> - Hierarchy packaging means "packaging directly from a single join sql", which is complementary to the cascading load in [Object CRUD](../crud/sqltoy_crud.md) (batch secondary queries by primary key).

> 🎬 Full runnable example: `HierarchyPackagingTest.java` in the demo project `sqltoy-showcase` (its `AbstractDictTypeVO` has `notNullField = "dictKey"` configured on @OneToMany).

#### Stored Procedure Calls

For the complete description and examples of stored procedure calls (`executeStore` / `executeMoreResultStore`, the fluent `store()`, out parameters, **multiple result sets**), see [Stored Procedures](store_procedure.md).

```java
// quick example: call a stored procedure and get the result set (pass null for outParamsType when there are no out parameters)
List result = lightDao.executeStore("{call storeName(?,?)}",
        new Object[]{ value1, value2 }, null, VO.class).getRows();
```
