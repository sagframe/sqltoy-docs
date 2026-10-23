# Object CRUD

sqltoy's object-oriented CRUD is quite similar to JPA. Its main features:  
1) POJOs are generated via quickvo, a tool similar to hibernate-tools  
2) Composite primary keys are supported, e.g. for update: lightDao.update(new StaffInfo("S0001","HUAWEI_SH").setName("Li Si"));  
3) Two API modes are provided: explicit shortcut APIs and chainable APIs. The chain API exposes more parameters, such as specifying a datasource, enabling parallelism, setting batchSize, e.g.  
   lightDao.update().dataSource(xxx).forceUpdateProps("status").batchSize(500).many(entities);  
4) There is no concept of logical delete; in sqltoy it is simply a status update  
5) Compared with JPA, sqltoy mainly optimizes update (providing the elastic update) and adds updateSaveFetch and updateFetch (one database interaction completes the locking query, update-or-insert and result return)  
6) sqltoy supports cascading in two forms, OneToOne and OneToMany (with some improvements, e.g. loading supports filtering), but only one level of cascading; query results are automatically packaged in layers based on annotations (hierarchy packaging), see [Query API](en/query/sqltoy_query.md)  
7) sqltoy optimizes cascade loading and cascade deletion under the hood, using id in (:ids) style queries and deletes, organizing the final data algorithmically to reduce database IO and improve efficiency  
8) For details see the org.sagacity.sqltoy.dao.LightDao interface, which is thoroughly documented

# 1. Save a Single Record

* API signature; to explicitly specify a datasource, use the chainable operation lightDao.save().dataSource(xxx).one(entity)

```java
/**
 * Save an object and return the primary key value
 * @param entity
 * @return Object returns the primary key value
 */
public Object save(Serializable entity);

/**
 * Chainable mode for saving a collection of objects, e.g.:
 *       lightDao.save().dataSource(xxx).one(entity)
 * @return
 */
public Save save();

```

* Simple example

```java
StaffInfo staffInfo = new StaffInfo();
staffInfo.setStaffCode("S2018");
staffInfo.setStaffName("Test Employee 9");
lightDao.save(staffInfo);
```
* Cascade save example

```java
// cascade configuration on the main object
@Schema(name="ComplexpkHead",description="complex primary-key cascade operation master table")
@Data
@Accessors(chain = true)
@Entity(tableName="sqltoy_complexpk_head",comment="complex primary-key cascade operation master table",pk_constraint="PRIMARY")
public class ComplexpkHead implements Serializable {
	
	/**
	 * Child table info associated by primary key
	 */
	@OneToMany(fields={"transDate","transCode"},mappedFields={"transDate","transId"},delete=true)
	private List<ComplexpkItem> complexpkItems=new ArrayList<ComplexpkItem>();
	
	// OneToOne configuration
	//@OneToOne(fields={"transDate","transCode"},mappedFields={"transDate","transId"},delete=true)
	//private ComplexpkItem complexpkItem;
}

@Test
public void testSaveCascade() {
	// master table record
	ComplexpkHead head = new ComplexpkHead();
	head.setTransDate(LocalDate.parse("2020-09-08"));
	head.setTransCode("S0001");
	head.setTotalCnt(BigDecimal.valueOf(10));
	head.setTotalAmt(BigDecimal.valueOf(10000));

	// child table record 1
	ComplexpkItem item1 = new ComplexpkItem();
	// the id is set manually here for easier demonstration
	item1.setId("S000101");
	item1.setProductId("P01");
	item1.setPrice(BigDecimal.valueOf(1000));
	item1.setAmt(BigDecimal.valueOf(5000));
	item1.setQuantity(BigDecimal.valueOf(5));
	head.getComplexpkItems().add(item1);

	// child table record 2
	ComplexpkItem item2 = new ComplexpkItem();
	item2.setId("S000102");
	item2.setProductId("P02");
	item2.setPrice(BigDecimal.valueOf(1000));
	item2.setAmt(BigDecimal.valueOf(5000));
	item2.setQuantity(BigDecimal.valueOf(5));
	head.getComplexpkItems().add(item2);

	lightDao.save(head);
}
```

# 2. Batch Save

* API signature; to explicitly specify a datasource, use the chainable operation lightDao.save().dataSource(xxx).many(entities)
* Large-scale parallel save: lightDao.save().parallelConfig(ParallelConfig.create().groupSize(5000).maxThreads(10)).many(entities)

```java
/**
 * Save objects in batch and return the number of records updated
 * @param <T>
 * @param entities
 * @return Long number of records changed in the database
 */
public <T extends Serializable> Long saveAll(List<T> entities);

/**
 * Save objects in batch, ignoring records that already exist
 * @param <T>
 * @param entities
 * @return Long number of records changed in the database
 */
public <T extends Serializable> Long saveAllIgnoreExist(List<T> entities);

/**
 * Chainable mode for saving a collection of objects, e.g.:
 *       lightDao.save().dataSource(xxx).many(entities)
         lightDao.save().parallelConfig(ParallelConfig.create().groupSize(5000).maxThreads(10)).many(entities)
 * @return
 */
public Save save();

```
# 3. Update a Single Record

* API signature: unlike JPA, sqltoy updates do not require querying and loading the entity first; simply set the primary key and the property values to be modified

```java
/**
 * Update data and return the number of records changed in the database (non-forced properties with null values do not participate in the update)
 * @param entity
 * @param forceUpdateProps properties to update forcibly
 * @return Long number of records changed in the database
 */
public Long update(Serializable entity, String... forceUpdateProps);

/**
 * Deep update: all fields are updated forcibly regardless of whether they are null
 * @param entity
 * @return Long number of records changed in the database
 */
public Long updateDeeply(Serializable entity);

/**
 * Chainable mode for updating records
 *       <li>lightDao.update().dataSource(xxx).forceUpdateProps("status").one(entity)</li>
 *       <li>lightDao.update().dataSource(xxx).forceUpdateProps("status").many(entities)</li>
 *       <li>Large-scale parallel: lightDao.update().parallelConfig(ParallelConfig.create().groupSize(5000).maxThreads(10)).forceUpdateProps("status").many(entities)</li>
 * @return
 */
public Update update();

/**
 * Cascade update data and return the number of records changed in the database
 * @param entity
 * @param forceUpdateProps
 * @param forceCascadeClasses when the cascade objects are null or empty, whether this means forcibly deleting the cascade records
 * @param subTableForceUpdateProps sets the properties to update forcibly on the cascade-updated objects
 * @return Long number of records changed in the database
 */
public Long updateCascade(Serializable entity, String[] forceUpdateProps, Class[] forceCascadeClasses,
		HashMap<Class, String[]> subTableForceUpdateProps);
```

* Simple update example

```java
// update the name and status of the employee with staff code S0001
lightDao.update(new StaffInfo("S0001").setName("Zhang San").setStatus(1));
// composite primary key (staff code, tenant)
lightDao.update(new StaffInfo("S0001","HUAWEI_SH").setName("Zhang San").setStatus(1));
```

* Cascade update example

```java
Map<Class,String[]> subTableForces=new HashMap<>();
subTableForces.put(ComplexpkItem.class,new String[]{"status"});

// for single-record updates, once cascadeForceUpdate or cascadeClasses is involved, cascade behavior is enabled; otherwise update only targets the object itself
lightDao.update().dataSource(crmDataSource).forceUpdateProps("status").cascadeForceUpdate(subTableForces).one(entity);
```

# 4. Batch Update

* API signatures

```java
/**
 * Batch update, with optional properties to update forcibly (non-forced properties with null values do not participate in the update)
 * @param <T>
 * @param entities
 * @param forceUpdateProps
 * @return Long number of records changed in the database
 */
public <T extends Serializable> Long updateAll(List<T> entities, String... forceUpdateProps);

/**
 * Batch deep update, i.e. all fields participate in the update (including null properties)
 * @param <T>
 * @param entities
 * @return Long number of records changed in the database
 */
public <T extends Serializable> Long updateAllDeeply(List<T> entities);
```

* Large-scale parallel update example

```java
lightDao.update().dataSource(crmDataSource).forceUpdateProps("status")
      .parallelConfig(ParallelConfig.create().groupSize(5000).maxThreads(10))
      .many(entities);
```

# 5. Update by Query Conditions (updateByQuery)

* Description: no need to load entities first — fields are batch-updated directly based on single-table query conditions, completed in a single database interaction. Suitable for scenarios like "uniformly updating certain fields of all records matching a condition" (logical delete is essentially a status update and can be implemented with it).

* API signature

```java
/**
 * Update data based on a single-table query
 * @param entityClass entity class
 * @param entityUpdate organizes the set fields and where conditions via EntityUpdate
 * @return Long number of records changed in the database
 */
public Long updateByQuery(Class entityClass, EntityUpdate entityUpdate);
```

* Usage example

```java
// change the gender of employee S0001 to F (set uses object property names; where uses ? placeholders with values passed in order)
lightDao.updateByQuery(StaffInfo.class,
        EntityUpdate.create().set("sexType", "F").where("staffId=?").values("S0001"));

// multi-field update + multiple conditions
lightDao.updateByQuery(OrderInfo.class,
        EntityUpdate.create()
            .set("status", 2)
            .set("updateTime", LocalDateTime.now())
            .where("organId=? and createTime<?")
            .values("T001", LocalDateTime.now().minusMonths(3)));

// specify the datasource; skipNotExistColumn() means set fields that do not exist in the table are skipped automatically
lightDao.updateByQuery(StaffInfo.class,
        EntityUpdate.create().dataSource(crmDataSource)
            .set("status", 0).where("staffId=?").values("S0001")
            .skipNotExistColumn());
```

> `EntityUpdate` chainable methods: `set(property, value)` (callable multiple times to set multiple fields), `where(condition)`, `values(values...)`, `blankToNull(Boolean)`, `skipNotExistColumn()`, `dataSource(...)`, `showSql(Boolean)`. Use `?` placeholders in `where`, with values passed in order via `values(...)`. It pairs with `deleteByQuery` (see the next section): one updates by condition, the other deletes by condition.

* Column self-increment / expression updates (`set field=field+?`)

Besides plain field names, the `set` key can also be written as **`field=expression`** to perform calculated updates based on a field's current value (self-increment, deduction, etc.). The `?` in the expression is bound by the `set` value; field names (e.g. `totalAmt`) are automatically converted to database column names (`total_amt`).

```java
// self update: total_amt = total_amt + 10
// equivalent SQL: update sqltoy_staff_info set total_amt=total_amt+10 where staff_name like 'Zhang'
lightDao.updateByQuery(StaffInfo.class,
        EntityUpdate.create()
            .set("totalAmt=totalAmt+?", 10)
            .where("staffName like ?").values("Zhang"));

// stock deduction: quantity = quantity - 5; plain field updates can be combined at the same time
lightDao.updateByQuery(OrderInfo.class,
        EntityUpdate.create()
            .set("quantity=quantity-?", 5)     // expression update (calculated from the field's current value)
            .set("status", 2)                  // plain field update (they can coexist)
            .where("orderId=?").values("10001"));
```

> Key point: always use `?` placeholders in expressions and pass the value through the `set` value (e.g. `set("totalAmt=totalAmt+?", 10)`); in a `set` key the left side is the field name and the right side is a SQL expression, which may include operators such as `+ - * /`. Expression updates can be mixed with plain `set(field, value)`; the framework binds parameters automatically in the order "set first, then where".

* In practice: logical delete (status update)

sqltoy has no standalone "logical delete" concept — a logical delete is essentially just updating a status/flag field (see the "Delete Operations" section below). For a single record the elastic update is enough; for batch by condition use `updateByQuery`, done in a single database interaction.

```java
// Option 1: single-record logical delete — elastic update, only status is changed (null fields do not participate in the update)
lightDao.update(new OrderInfo("10001").setStatus(0));

// Option 2: batch logical delete by condition — updateByQuery
// mark orders of a department older than 3 months with status 1 as deleted (0), recording the operator/time
lightDao.updateByQuery(OrderInfo.class,
        EntityUpdate.create()
            .set("status", 0)
            .set("updateBy", "S0001")
            .set("updateTime", LocalDateTime.now())
            .where("organId=? and status=? and createTime<?")
            .values("T001", 1, LocalDateTime.now().minusMonths(3)));
```

Exclude logically deleted records when querying (just add the status condition in the SQL):

```xml
<sql id="find_order">
    <value><![CDATA[
        select * from sqltoy_order_info t
        where t.status<>0          -- exclude logically deleted
        #[and t.organ_id=:organId]
    ]]></value>
</sql>
```

> Tip: if a [unified field handler](en/quickstart/helloworld_improve.md) (`unifyFieldsHandler`) is configured, object-style `update` automatically fills in missing `updateBy`/`updateTime`; with `updateByQuery` it is recommended to explicitly `set` the audit fields as shown above.

# 6. Delete Operations

* sqltoy has no concept of logical delete  
  (a logical delete is essentially updating a status or flag field; use update operations instead)


* API signatures

```java
/**
 * Chainable mode for delete operations, examples:
 *       <li>lightDao.delete().dataSource(xxxx).one(entity);</li>
 *       <li>lightDao.delete().batchSize(1000).autoCommit(true).many(entities);</li>
 *       <li>lightDao.delete().parallelConfig(ParallelConfig.create().groupSize(5000).maxThreads(10)).many(entities);</li>
 * @return
 */
public Delete delete();
	
/**
 * Delete a single object and return the number of records affected in the database
 * @param entity
 * @return Long number of records changed in the database (number of deleted records)
 */
public Long delete(final Serializable entity);

/**
 * Delete objects in batch and return the number of records affected in the database
 * @param entities
 * @return Long number of records changed in the database (number of deleted records)
 */
public <T extends Serializable> Long deleteAll(final List<T> entities);

/**
 * Batch delete by a collection of ids
 * @param entityClass
 * @param ids
 * @return
 */
public Long deleteByIds(Class entityClass, Object... ids);

/**
 * Delete based on a single-table query, providing a shortcut operation in code
 * @param entityClass
 * @param entityQuery e.g.: lightDao.deleteByQuery(DictDetail.class,EntityQuery.create().where("status=?").values(0));
 * @return Long number of records changed in the database (number of inserted records)
 */
public Long deleteByQuery(Class entityClass, EntityQuery entityQuery);
```

* Usage example

```java
// composite primary key
lightDao.delete(new StaffInfo("S0001","HUAWEI_SH"));
// single primary key, delete multiple records
lightDao.deleteByIds(OrderInfo.class,"10001","10002");
// delete data matching the conditions
lightDao.deleteByQuery(DictDetail.class,EntityQuery.create().dataSource(xxxx).where("status=?").values(0));
```

# 7. saveOrUpdate Operations

* Description  
  1) The saveOrUpdate logic: if the record exists it is updated; if it does not exist it is created (a null primary key value always means creation)  
  2) MySQL-family databases use update first then insert ignore; others use the merge into mode

* API signatures

```java
/**
 * Chainable mode for saving a collection of objects, e.g.:
 *    <li>lightDao.save().dataSource(xxx).saveMode(SaveMode.UPDATE).many(entities)</li>
 * @return
 */
public Save save();
	
/**
 * Save or update data and return the number of records changed in the database
 * @param entity
 * @param forceUpdateProps fields to update forcibly
 * @return Long number of records changed in the database
 */
public Long saveOrUpdate(Serializable entity, String... forceUpdateProps);

/**
 * Batch save or update (updates when the record already exists)
 * @param <T>
 * @param entities
 * @param forceUpdateProps fields to update forcibly
 * @return Long number of records changed in the database
 */
public <T extends Serializable> Long saveOrUpdateAll(List<T> entities, String... forceUpdateProps);
```

* Usage example

```java
// simple batch save or update
lightDao.saveOrUpdateAll(entities,"name","status","quantity");

// SaveMode has three values: APPEND\UPDATE\IGNORE
lightDao.save().dataSource(xxx).saveMode(SaveMode.UPDATE)
	.parallelConfig(ParallelConfig.create().groupSize(5000).maxThreads(10)).many(entities);
```

# 8. Object Loading

* API signatures

```java
/**
 * Chainable mode for object loading operations
 *    <li>lightDao.load().dataSource(xxxx).lock(LockMode.UPGRADE_NOWAIT).one(new StaffInfo("S0001"));</li>
 *    <li>lightDao.load().parallelConfig(ParallelConfig.create().groupSize(5000).maxThreads(10)).many(entities);</li>
 *    <li>Load the main objects and cascade-load the child objects: lightDao.load().cascade(OrderItem.class,OrderDeliveryPlan.class).many(entities);</li>
 *    <li>Cascade-load the child objects only by the main objects' primary keys: lightDao.load().cascade(OrderItem.class,OrderDeliveryPlan.class).onlyCascade().many(entities);</li>
 * @return
 */
public Load load();

/**
 * Load the details of an object by its primary key value
 * @param entity
 * @return entity
 */
public <T extends Serializable> T load(final T entity);

/**
 * Load a single entity object by primary key
 * @param <T>
 * @param entityClass
 * @param id
 * @return
 */
public <T extends Serializable> T loadById(final Class<T> entityClass, Object id);

/**
 * Load an object by primary key, with a read lock setting
 * @param entity
 * @param lockMode LockMode.UPGRADE or LockMode.UPGRADE_NOWAIT, etc.
 * @return entity
 */
public <T extends Serializable> T load(final T entity, final LockMode lockMode);

/**
 * Load an object while specifying the child classes to load, achieving cascade loading
 * @param entity
 * @param lockMode
 * @param cascadeTypes
 * @return entity
 */
public <T extends Serializable> T loadCascade(final T entity, final LockMode lockMode, final Class... cascadeTypes);

/**
 * Load entity details by the primary keys in the collection (optimized under the hood with batch loading, while handling the in-1000 issue)
 * @param entities
 * @return entities
 */
public <T extends Serializable> List<T> loadAll(List<T> entities);

/**
 * Batch loading with record locking
 * @param <T>
 * @param entities
 * @param lockMode
 * @return
 */
public <T extends Serializable> List<T> loadAll(List<T> entities, final LockMode lockMode);

/**
 * Batch load objects by a collection of ids
 * @param <T>
 * @param entityClass
 * @param ids
 * @return
 */
public <T extends Serializable> List<T> loadByIds(final Class<T> entityClass, Object... ids);

/**
 * Batch load objects by a collection of ids, with locking
 * @param <T>
 * @param entityClass
 * @param lockMode
 * @param ids
 * @return
 */
public <T extends Serializable> List<T> loadByIds(final Class<T> entityClass, final LockMode lockMode,
		Object... ids);

/**
 * Selectively load child table information
 * @param entities
 * @param cascadeTypes
 * @return
 */
public <T extends Serializable> List<T> loadAllCascade(List<T> entities, final Class... cascadeTypes);

/**
 * Lock the main table records and cascade-load the child table data
 * @param <T>
 * @param entities
 * @param lockMode
 * @param cascadeTypes
 * @return
 */
public <T extends Serializable> List<T> loadAllCascade(List<T> entities, final LockMode lockMode,
		final Class... cascadeTypes);
```

* Large-scale parallel loading example

```java
lightDao.load().parallelConfig(ParallelConfig.create().groupSize(5000).maxThreads(10)).many(entities);
```

* Cascade loading

```java
lightDao.load().cascade(OrderItem.class,OrderDeliveryPlan.class).many(entities);

lightDao.loadCascade(new OrderInfo("S0001"), null, OrderItem.class,OrderDeliveryPlan.class);

```

* Cascade-load the child objects only (child objects are constructed onto the corresponding properties of the main objects)

```java
// .onlyCascade() queries the child objects only via the primary keys of the pojos in the entities collection; the main objects are no longer queried
lightDao.load().cascade(OrderItem.class,OrderDeliveryPlan.class).onlyCascade().many(entities);

```

# 9. updateSaveFetch (locking query → update if exists / insert if not → return the result, in one interaction)

* Description  
  1) Unique to sqltoy (JPA does not have it): **a single database interaction** completes the locking query + update-if-exists / insert-if-not-exists + returning the updated or inserted record  
  2) Applicable scenarios: high-concurrency, strongly transactional ledgers such as inventory and customer fund accounts — the "update if exists, initialize-and-insert if not" upsert semantics naturally avoids the concurrent first-query race (when two requests both find the record missing, only one insert succeeds; the other falls back to updating)  
  3) **Prefer it over updateFetch for such scenarios**: it locates the record by entity + primary/unique key, no SQL needed; the insert happens automatically when the record does not exist, so callers never check existence first. updateFetch (next section) targets scenarios where the record **must already exist** and the query conditions and lock strategy need to be freely authored

* API (three common overloads; uniqueProps can be omitted to query by primary key)

```java
/**
 * Designed for high-concurrency, strongly transactional scenarios such as inventory ledgers and customer fund accounts; a single database interaction accomplishes:
 * 1. locking query; 2. update if the record exists; 3. insert if the record does not exist; 4. return the updated or inserted record information
 */
public <T extends Serializable> T updateSaveFetch(final T entity, final UpdateRowHandler updateRowHandler,
        final String... uniqueProps);

// entity-callback form (recommended): inside the callback you only touch entity getters/setters, no ResultSet
public <T extends Serializable> T updateSaveFetch(final T entity, final EntityUpdateCallback<T> callback,
        final String... uniqueProps);

// form with lock wait timeout (in seconds)
public <T extends Serializable> T updateSaveFetch(final T entity, final EntityUpdateCallback<T> callback,
        final int lockWaitTimeout, final String... uniqueProps);
```

* Usage example

```xml
// add the dependency class (the entity-callback form relies on byte-buddy to back the proxied entity)
<dependency>
    <groupId>net.bytebuddy</groupId>
    <artifactId>byte-buddy</artifactId>
    <version>1.18.15</version>
</dependency>
```

```java
@Test
public void testUpdateSaveFetch() {
    StaffInfoVO staffInfo = new StaffInfoVO();
    staffInfo.setStaffId("S0001");
    staffInfo.setBeginDate(LocalDate.parse("2019-01-01"));
    staffInfo.setEndDate(LocalDate.now());
    staffInfo.setStaffName("Chen");
    lightDao.updateSaveFetch(staffInfo, (entity, rowIndex) -> {
        // the entity getter here actually goes through a proxy, reading the value via rs.getString("tel_no")
        String telNo = entity.getTelNo();
        if (telNo != null) {
            // the setter here actually maps to rs.updateString("tel_no", telNo.substring(0, 3) + "#**#" +
            // telNo.substring(7));
            entity.setTelNo(telNo.substring(0, 3) + "#**#" + telNo.substring(7));
        }
    });
}
```

> [!NOTE]
> The `entity` inside the `EntityUpdateCallback` is a **proxied object**: getters read the current database value (`rs.getXxx`) and setters update the row directly (`rs.updateXxx`) — no manual ResultSet synchronization. Throwing inside the callback rolls the whole operation back.

* Notes  
  1) Avoid identity / sequence primary keys on the entity (when the record does not exist and an insert happens, carrying the key in the entity is the most straightforward)  
  2) For business-unique-key scenarios (e.g. a ledger located by "product + date" rather than primary key), pass the property names via `uniqueProps`; omit it to query by primary key  
  3) Under fierce contention prefer the `lockWaitTimeout` overload to set the lock wait explicitly (in seconds); a lock wait timeout throws and rolls back  
  4) Under GraalVM native images the `EntityUpdateCallback` form relies on byte-buddy proxy subclasses: configure `native-entity-proxies` to pre-generate them at build time (entities not listed are unusable; the insert branch is not affected); see the [GraalVM Native guide](en/tools/graalvm_native.md)

# 10. updateFetch (SQL-authored locking query → validate and update → return results, in one interaction)

* Description  
  1) Unique to sqltoy (JPA does not have it): **a single database interaction** completes query + locking + logical validation + update + returning the updated results  
  2) Applicable scenarios: strongly transactional steps where the record **must already exist** and the query conditions need to be freely authored (multi-table joins, complex conditions, explicit lock strategy) — the purpose of the query is to **lock the records for logical validation** (e.g. the value must not drop below 0 after deduction); the update happens only after validation passes  
  3) For ledger scenarios where the record may not exist and is located by primary/unique key, prefer `updateSaveFetch` above (automatic upsert)

> [!WARNING]
> The core purpose of updateFetch is **data logical validation** (e.g. the value must not drop below 0 after deduction). **Do not use this method for display-oriented page queries.**

* API

```java
/**
 * Fetch and lock data, then update it (usually a simple query: lock the records, validate logically, then update)
 * @param queryExecutor    query executor, defining the query SQL, condition parameters and lock strategy
 * @param updateRowHandler row update callback handler that validates and modifies the row data, then submits the update
 * @return the updated row records
 */
public List updateFetch(final QueryExecutor queryExecutor, final UpdateRowHandler updateRowHandler);
```

* Usage example (stock deduction: lock → validate sufficient stock → deduct → return the latest data)

```java
List result = lightDao.updateFetch(
        // simple query + pessimistic lock strategy
        new QueryExecutor("sqltoy_stock_find")
                .names("productId").values("P0001")
                .lock(LockMode.UPGRADE),
        // Note: UpdateRowHandler's methods are all default; it is not a functional interface, so override via an anonymous class
        new UpdateRowHandler() {
            @Override
            public void updateRow(ResultSet rs, int index, BiConsumer<String, Object> setVal) throws Exception {
                double quantity = rs.getDouble("quantity");
                if (quantity < 1) {
                    // if logical validation fails, throw directly; the whole update rolls back
                    throw new IllegalArgumentException("Insufficient stock!");
                }
                // set the updated value via the callback: <property name, new value>
                setVal.accept("quantity", quantity - 1);
            }
        });
```

> `UpdateRowHandler` provides three overridable methods: `updateRow(rs,index)`, `updateRow(rs,index,BiConsumer<property,value>)`, `updateRow(rs,index,ThreeBiConsumer<property,forced update fields[],value>)` (the third one allows specifying forced-update fields).
>
> It complements `updateSaveFetch` in the previous section: `updateSaveFetch` locates the record by entity and inserts automatically when missing; `updateFetch` updates **existing** records, with query conditions freely authored in SQL.
