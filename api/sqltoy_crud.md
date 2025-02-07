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
* 级联修改使用范例

```java
Map<Class,String[]> subTableForces=new HashMap<>();
subTableForces.put(ComplexpkItem.class,new String[]{"status"});
lightDao.update().dataSource(crmDataSource).forceUpdateProps("status").cascadeForceUpdate(subTableForces).one(entity);
```

# 4、批量修改

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
