# 说明
* sqltoy的对象化crud跟JPA比较类似，主要特点:  
1) 通过quickvo类似hibernate-tools工具产生POJO  
2) 支持复合主键，如update操作lightDao.update(new StaffInfo("S0001","HUAWEI_SH").setName("李四"));  
3) 提供显式快捷api和链式api 2种模式,链式API提供更多的参数,如指定数据源、设定并行、设定batchSize等参数,如  
   lightDao.update().dataSource(xxx).forceUpdateProps("status").batchSize(500).many(entities);  
4) 没有逻辑删除的概念,在sqltoy中就是状态更新  
5) 相比较于JPA，sqltoy主要优化了update(提供了弹性修改)，新增了updateFetch和updateSaveFetch  
6) sqltoy支持:OneToOne 和 OneToMany 两种形式的级联(有部分改进,如:加载支持过滤等)，但只支持一级级联  
7) sqltoy在级联加载和级联删除等操作上底层做了优化,采用了id in (:ids)形式的查询和删除,用算法组织最终数据，减少数据库IO提升效率  
8) 详细请参见:org.sagacity.sqltoy.dao.LightDao接口,其有详细备注

# 1、单条记录保存
* 接口规范，涉及显式指定数据源，可用lightDao.save().dataSource(xxx).one(entity)链式操作

```java
/**
 * @todo 保存对象,并返回主键值
 * @param entity
 * @return Object 返回主键值
 */
public Object save(Serializable entity);

/**
 * @TODO 提供链式操作模式保存操作集合,如:
 *       lightDao.save().dataSource(xxx).one(entity)
 * @return
 */
public Save save();

```

* 简单范例

```java
StaffInfo staffInfo = new StaffInfo();
staffInfo.setStaffCode("S2018");
staffInfo.setStaffName("测试员工9");
lightDao.save(staffInfo);
```
* 级联保存范例

```java
//主对象中配置级联信息
@Schema(name="ComplexpkHead",description="复合主键级联操作主表")
@Data
@Accessors(chain = true)
@Entity(tableName="sqltoy_complexpk_head",comment="复合主键级联操作主表",pk_constraint="PRIMARY")
public class ComplexpkHead implements Serializable {
	
	/**
	 * 主键关联子表信息
	 */
	@OneToMany(fields={"transDate","transCode"},mappedFields={"transDate","transId"},delete=true)
	private List<ComplexpkItem> complexpkItems=new ArrayList<ComplexpkItem>();
	
	//OneToOne的配置
	//@OneToOne(fields={"transDate","transCode"},mappedFields={"transDate","transId"},delete=true)
	//private ComplexpkItem complexpkItem;
}

@Test
public void testSaveCascade() {
	// 主表记录
	ComplexpkHead head = new ComplexpkHead();
	head.setTransDate(LocalDate.parse("2020-09-08"));
	head.setTransCode("S0001");
	head.setTotalCnt(BigDecimal.valueOf(10));
	head.setTotalAmt(BigDecimal.valueOf(10000));

	// 子表记录1
	ComplexpkItem item1 = new ComplexpkItem();
	// 这里id是为了便于演示手工指定
	item1.setId("S000101");
	item1.setProductId("P01");
	item1.setPrice(BigDecimal.valueOf(1000));
	item1.setAmt(BigDecimal.valueOf(5000));
	item1.setQuantity(BigDecimal.valueOf(5));
	head.getComplexpkItemVOs().add(item1);

	// 子表记录2
	ComplexpkItem item2 = new ComplexpkItem();
	item2.setId("S000102");
	item2.setProductId("P02");
	item2.setPrice(BigDecimal.valueOf(1000));
	item2.setAmt(BigDecimal.valueOf(5000));
	item2.setQuantity(BigDecimal.valueOf(5));
	head.getComplexpkItemVOs().add(item2);

	lightDao.save(head);
}
```

# 2、批量保存

* 接口规范，涉及显式指定数据源，可用lightDao.save().dataSource(xxx).many(entities)链式操作
* 大批量并行保存:lightDao.save().parallelConfig(ParallelConfig.create().groupSize(5000).maxThreads(10)).many(entities)

```java
/**
 * @TODO 批量保存对象，并返回数据更新记录量
 * @param <T>
 * @param entities
 * @return Long 数据库发生变更的记录量
 */
public <T extends Serializable> Long saveAll(List<T> entities);

/**
 * @TODO 批量保存对象并忽视已经存在的记录
 * @param <T>
 * @param entities
 * @return Long 数据库发生变更的记录量
 */
public <T extends Serializable> Long saveAllIgnoreExist(List<T> entities);

/**
 * @TODO 提供链式操作模式保存操作集合,如:
 *       lightDao.save().dataSource(xxx).many(entities)
         lightDao.save().parallelConfig(ParallelConfig.create().groupSize(5000).maxThreads(10)).many(entities)
 * @return
 */
public Save save();

```
# 3、单笔记录修改

* 接口规范:sqltoy的更新不同于JPA需要先查询加载实体对象,直接赋予主键和需要修改的属性值即可

```java
/**
 * @todo 修改数据并返回数据库记录变更数量(非强制修改属性，当属性值为null不参与修改)
 * @param entity
 * @param forceUpdateProps 强制修改的字段属性
 * @return Long 数据库发生变更的记录量
 */
public Long update(Serializable entity, String... forceUpdateProps);

/**
 * @todo 深度修改,不管是否为null全部字段强制修改
 * @param entity
 * @return Long 数据库发生变更的记录量
 */
public Long updateDeeply(Serializable entity);

/**
 * @TODO 提供链式操作模式修改记录
 *       <li>lightDao.update().dataSource(xxx).forceUpdateProps("status").one(entity)</li>
 *       <li>lightDao.update().dataSource(xxx).forceUpdateProps("status").many(entities)</li>
 *       <li>大批量并行:lightDao.update().parallelConfig(ParallelConfig.create().groupSize(5000).maxThreads(10)).forceUpdateProps("status").many(entities)</li>
 * @return
 */
public Update update();

/**
 * @todo 级联修改数据并返回数据库记录变更数量
 * @param entity
 * @param forceUpdateProps
 * @param forceCascadeClasses 级联对象为null或空时，是否表示强制删除级联记录
 * @param subTableForceUpdateProps 设置级联修改对象强制修改的属性
 * @return Long 数据库发生变更的记录量
 */
public Long updateCascade(Serializable entity, String[] forceUpdateProps, Class[] forceCascadeClasses,
		HashMap<Class, String[]> subTableForceUpdateProps);
```

* 简单更新使用范例

```java
//对工号S0001的员工更新姓名和状态
lightDao.update(new StaffInfo("S0001").setName("张三").setStatus(1));
//复合主键（工号、租户)
lightDao.update(new StaffInfo("S0001","HUAWEI_SH").setName("张三").setStatus(1));
```

* 级联修改使用范例

```java
Map<Class,String[]> subTableForces=new HashMap<>();
subTableForces.put(ComplexpkItem.class,new String[]{"status"});

//单条记录修改一旦涉及cascadeForceUpdate或cascadeClasses 就开启了级联行为，否则update只针对自身
lightDao.update().dataSource(crmDataSource).forceUpdateProps("status").cascadeForceUpdate(subTableForces).one(entity);
```

# 4、批量修改

* api规范

```java
/**
 * @TODO 批量修改操作，并可以指定强制修改的属性(非强制修改属性，当属性值为null不参与修改)
 * @param <T>
 * @param entities
 * @param forceUpdateProps
 * @return Long 数据库发生变更的记录量
 */
public <T extends Serializable> Long updateAll(List<T> entities, String... forceUpdateProps);

/**
 * @TODO 批量深度修改，即全部字段参与修改(包括为null的属性)
 * @param <T>
 * @param entities
 * @return Long 数据库发生变更的记录量
 */
public <T extends Serializable> Long updateAllDeeply(List<T> entities);
```

* 大批量并行更新范例

```java
lightDao.update().dataSource(crmDataSource).forceUpdateProps("status")
      .parallelConfig(ParallelConfig.create().groupSize(5000).maxThreads(10))
      .many(entities);
```

# 5、删除操作
* sqltoy没有逻辑删除的概念  
  (逻辑删除本质就是更新状态或更新标记字段，请用更新操作代替)


* api规范

```java
/**
 * @TODO 提供链式操作模式删除操作集合 示例:
 *       <li>lightDao.delete().dataSource(xxxx).one(entity);</li>
 *       <li>lightDao.delete().batchSize(1000).autoCommit(true).many(entities);</li>
 *       <li>lightDao.delete().parallelConfig(ParallelConfig.create().groupSize(5000).maxThreads(10)).many(entities);</li>
 * @return
 */
public Delete delete();
	
/**
 * @todo 删除单条对象并返回数据库记录影响的数量
 * @param entity
 * @return Long 数据库发生变更的记录量(删除数据量)
 */
public Long delete(final Serializable entity);

/**
 * @todo 批量删除对象并返回数据库记录影响的数量
 * @param entities
 * @return Long 数据库记录变更量(删除数据量)
 */
public <T extends Serializable> Long deleteAll(final List<T> entities);

/**
 * @TODO 根据id集合批量删除
 * @param entityClass
 * @param ids
 * @return
 */
public Long deleteByIds(Class entityClass, Object... ids);

/**
 * @TODO 基于单表查询进行删除操作,提供在代码中进行快捷操作
 * @param entityClass
 * @param entityQuery 例如:lightDao.deleteByQuery(DictDetail.class,EntityQuery.create().where("status=?").values(0));
 * @return Long 数据库记录变更量(插入数据量)
 */
public Long deleteByQuery(Class entityClass, EntityQuery entityQuery);
```

* 使用范例

```java
//复合主键
lightDao.delete(new StaffInfo("S0001","HUAWEI_SH"));
//单主键，删除多条
lightDao.deleteByIds(OrderInfo.class,"10001"，"10002");
//删除符合条件的数据
lightDao.deleteByQuery(DictDetail.class,EntityQuery.create().dataSource(xxxx).where("status=?").values(0));
```

# 6、saveOrUpdate操作
* 说明  
  1) saveOrUpdate的逻辑是记录存在就做修改操作，如果不存在则新建(主键值为null则必然是新建)  
  2) 类mysql数据库采用先update后insert ignore方式，其他采用merge into 模式

* api规范

```java
/**
 * @TODO 提供链式操作模式保存操作集合,如:
 *    <li>lightDao.save().dataSource(xxx).saveMode(SaveMode.UPDATE).many(entities)</li>
 * @return
 */
public Save save();
	
/**
 * @todo 保存或修改数据并返回数据库记录变更数量
 * @param entity
 * @param forceUpdateProps 强制修改的字段
 * @return Long 数据库发生变更的记录量
 */
public Long saveOrUpdate(Serializable entity, String... forceUpdateProps);

/**
 * @TODO 批量保存或修改操作(当已经存在就执行修改)
 * @param <T>
 * @param entities
 * @param forceUpdateProps 强制修改的字段
 * @return Long 数据库发生变更的记录量
 */
public <T extends Serializable> Long saveOrUpdateAll(List<T> entities, String... forceUpdateProps);
```

* 使用范例

```java
//简单批量保存或修改
lightDao.saveOrUpdateAll(entities,"name","status","quantity");

//SaveMode分:APPEND\UPDATE\IGNORE三种
lightDao.save().dataSource(xxx).saveMode(SaveMode.UPDATE)
	.parallelConfig(ParallelConfig.create().groupSize(5000).maxThreads(10)).many(entities);
```

* 7、对象加载

* api规范

```java
/**
 * @TODO 提供链式操作模式对象加载操作集合
 *    <li>lightDao.load().dataSource(xxxx).lock(LockMode.UPGRADE_NOWAIT).one(new StaffInfo("S0001"));</li>
 *    <li>lightDao.load().parallelConfig(ParallelConfig.create().groupSize(5000).maxThreads(10)).many(entities);</li>
 *    <li>加载主对象，同时级联加载子对象:lightDao.load().cascade(OrderItem.class,OrderDeliveryPlan.class).many(entities);</li>
 *    <li>只根据主对象的主键级联加载子对象:lightDao.load().cascade(OrderItem.class,OrderDeliveryPlan.class).onlyCascade().many(entities);</li>
 * @return
 */
public Load load();

/**
 * @todo 根据实体对象的主键值获取对象的详细信息
 * @param entity
 * @return entity
 */
public <T extends Serializable> T load(final T entity);

/**
 * @TODO 根据主键获取单个实体对象
 * @param <T>
 * @param entityClass
 * @param id
 * @return
 */
public <T extends Serializable> T loadById(final Class<T> entityClass, Object id);

/**
 * @todo 根据主键获取对象,提供读取锁设定
 * @param entity
 * @param lockMode LockMode.UPGRADE 或LockMode.UPGRADE_NOWAIT等
 * @return entity
 */
public <T extends Serializable> T load(final T entity, final LockMode lockMode);

/**
 * @todo 对象加载同时指定加载子类，实现级联加载
 * @param entity
 * @param lockMode
 * @param cascadeTypes
 * @return entity
 */
public <T extends Serializable> T loadCascade(final T entity, final LockMode lockMode, final Class... cascadeTypes);

/**
 * @todo 根据集合中的主键获取实体的详细信息(底层是批量加载优化了性能,同时控制了in 1000个问题)
 * @param entities
 * @return entities
 */
public <T extends Serializable> List<T> loadAll(List<T> entities);

/**
 * @todo 提供带锁记录的批量加载功能
 * @param <T>
 * @param entities
 * @param lockMode
 * @return
 */
public <T extends Serializable> List<T> loadAll(List<T> entities, final LockMode lockMode);

/**
 * @TODO 根据id集合批量加载对象
 * @param <T>
 * @param entityClass
 * @param ids
 * @return
 */
public <T extends Serializable> List<T> loadByIds(final Class<T> entityClass, Object... ids);

/**
 * @TODO 根据id集合批量加载对象,并加锁
 * @param <T>
 * @param entityClass
 * @param lockMode
 * @param ids
 * @return
 */
public <T extends Serializable> List<T> loadByIds(final Class<T> entityClass, final LockMode lockMode,
		Object... ids);

/**
 * @todo 选择性的加载子表信息
 * @param entities
 * @param cascadeTypes
 * @return
 */
public <T extends Serializable> List<T> loadAllCascade(List<T> entities, final Class... cascadeTypes);

/**
 * @TODO 锁住主表记录并级联加载子表数据
 * @param <T>
 * @param entities
 * @param lockMode
 * @param cascadeTypes
 * @return
 */
public <T extends Serializable> List<T> loadAllCascade(List<T> entities, final LockMode lockMode,
		final Class... cascadeTypes);
```

* 大规模并行加载范例

```java
lightDao.load().parallelConfig(ParallelConfig.create().groupSize(5000).maxThreads(10)).many(entities);
```

* 级联加载

```java
lightDao.load().cascade(OrderItem.class,OrderDeliveryPlan.class).many(entities);

lightDao.loadCascade(new OrderInfo("S0001"), null, OrderItem.class,OrderDeliverPlan.class);

```

* 仅级联加载子对象(将子对象构造到主对象的对应属性上)

```java
//.onlyCascade()即只会通过entities集合pojo的主键关联查询子对象，主对象不再做查询行为
lightDao.load().cascade(OrderItem.class,OrderDeliveryPlan.class).onlyCascade().many(entities);

```

