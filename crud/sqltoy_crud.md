# 说明
* sqltoy的对象化crud跟JPA比较类似，主要特点:  
1) 通过quickvo类似hibernate-tools工具产生POJO  
2) 支持复合主键，如update操作lightDao.update(new StaffInfo("S0001","HUAWEI_SH").setName("李四"));  
3) 提供显式快捷api和链式api 2种模式,链式API提供更多的参数,如指定数据源、设定并行、设定batchSize等参数,如  
   lightDao.update().dataSource(xxx).forceUpdateProps("status").batchSize(500).many(entities);  
4) 没有逻辑删除的概念,在sqltoy中就是状态更新  
5) 相比较于JPA，sqltoy主要优化了update(提供了弹性修改)，新增了updateFetch和updateSaveFetch  
6) sqltoy支持:OneToOne 和 OneToMany 两种形式的级联(有部分改进,如:加载支持过滤等)，但只支持一级级联；查询结果依据注解自动分层封装(hiberarchy)见[常规查询 API](../query/sqltoy_query.md)  
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

# 5、基于查询条件修改（updateByQuery）

* 说明：无需先加载实体对象，直接基于单表查询条件批量修改字段，一次数据库交互即可完成。适用于"把符合条件的记录的某些字段统一更新"的场景（逻辑删除本质也是状态更新，可用它实现）。

* api规范

```java
/**
 * @TODO 基于单表查询完成数据修改
 * @param entityClass 实体类
 * @param entityUpdate 通过 EntityUpdate 组织 set 修改字段与 where 条件
 * @return Long 数据库发生变更的记录量
 */
public Long updateByQuery(Class entityClass, EntityUpdate entityUpdate);
```

* 使用范例

```java
// 将工号 S0001 的员工性别改为 F（set 用对象属性名，where 用 ? 占位、values 按序传值）
lightDao.updateByQuery(StaffInfo.class,
        EntityUpdate.create().set("sexType", "F").where("staffId=?").values("S0001"));

// 多字段更新 + 多条件
lightDao.updateByQuery(OrderInfo.class,
        EntityUpdate.create()
            .set("status", 2)
            .set("updateTime", LocalDateTime.now())
            .where("organId=? and createTime<?")
            .values("T001", LocalDateTime.now().minusMonths(3)));

// 指定数据源；skipNotExistColumn() 表示 set 的字段在表中不存在时自动跳过
lightDao.updateByQuery(StaffInfo.class,
        EntityUpdate.create().dataSource(crmDataSource)
            .set("status", 0).where("staffId=?").values("S0001")
            .skipNotExistColumn());
```

> `EntityUpdate` 链式方法：`set(属性, 值)`（可多次调用设置多个字段）、`where(条件)`、`values(值...)`、`blankToNull(Boolean)`、`skipNotExistColumn()`、`dataSource(...)`、`showSql(Boolean)`。`where` 中使用 `?` 占位、由 `values(...)` 按顺序传值。与 `deleteByQuery`（见下节）相对应，一个按条件改、一个按条件删。

* 列自增 / 表达式更新（`set 字段=字段+?`）

`set` 的 key 除了写普通字段名，还可以写成 **`字段=表达式`** 形式，实现基于字段当前值的计算更新（自增、扣减等）。表达式中的 `?` 由 `set` 的 value 绑定；字段名（如 `totalAmt`）会自动转换为数据库列名（`total_amt`）。

```java
// 自更新：total_amt = total_amt + 10
// 等价 SQL：update sqltoy_staff_info set total_amt=total_amt+10 where staff_name like '张'
lightDao.updateByQuery(StaffInfo.class,
        EntityUpdate.create()
            .set("totalAmt=totalAmt+?", 10)
            .where("staffName like ?").values("张"));

// 库存扣减：quantity = quantity - 5，可同时叠加普通字段更新
lightDao.updateByQuery(OrderInfo.class,
        EntityUpdate.create()
            .set("quantity=quantity-?", 5)     // 表达式更新（基于字段当前值计算）
            .set("status", 2)                  // 普通字段更新（可并存）
            .where("orderId=?").values("10001"));
```

> 要点：表达式务必用 `?` 占位、并由 `set` 的 value 传值（如 `set("totalAmt=totalAmt+?", 10)`）；`set` 的 key 左侧是字段名、右侧是 SQL 表达式，可包含 `+ - * /` 等运算。表达式更新可与普通 `set(字段, 值)` 混用，框架会自动按"先 set 后 where"的顺序绑定参数。

* 实战：逻辑删除（状态更新）

sqltoy 没有独立的"逻辑删除"概念——逻辑删除本质就是把状态/标记字段更新一下（参见下节"删除操作"说明）。单条用弹性更新即可，按条件批量则用 `updateByQuery`，一次数据库交互完成。

```java
// 方式一：单条逻辑删除——弹性更新，只改 status（为 null 的字段不参与更新）
lightDao.update(new OrderInfo("10001").setStatus(0));

// 方式二：按条件批量逻辑删除——updateByQuery
// 把某部门 3 个月前、状态为 1 的订单标记为已删除(0)，并记录操作人/时间
lightDao.updateByQuery(OrderInfo.class,
        EntityUpdate.create()
            .set("status", 0)
            .set("updateBy", "S0001")
            .set("updateTime", LocalDateTime.now())
            .where("organId=? and status=? and createTime<?")
            .values("T001", 1, LocalDateTime.now().minusMonths(3)));
```

查询时排除已逻辑删除的记录（在 sql 中加状态条件即可）：

```xml
<sql id="find_order">
    <value><![CDATA[
        select * from sqltoy_order_info t
        where t.status<>0          -- 排除已逻辑删除
        #[and t.organ_id=:organId]
    ]]></value>
</sql>
```

> 提示：若配置了[统一字段处理器](../quickstart/helloworld_improve.md)（`unifyFieldsHandler`），对象化 `update` 会自动补漏 `updateBy`/`updateTime`；用 `updateByQuery` 时建议如上显式 `set` 审计字段。

# 6、删除操作
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

# 7、saveOrUpdate操作
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

# 8、对象加载

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

# 9、updateFetch操作（锁查询→校验修改→返回结果，一次交互）

* 说明  
  1) sqltoy 独有（JPA 没有）：**一次数据库交互**完成 查询+锁定+逻辑校验+修改+返回修改后结果  
  2) 适用场景：秒杀、库存台账、资金台账等高并发强事务环节——查询的目的是**锁住记录做逻辑校验**（如扣减后不能小于 0），校验通过才修改  
  3) ⚠️ 官方警示：updateFetch 的核心目的是**数据逻辑校验**，页面展示性查询不要用此方法

* api

```java
/**
 * 获取并锁定数据并进行修改（一般为简单查询，锁住记录进行逻辑校验后修改）
 * @param queryExecutor    查询执行器，定义查询的sql、条件参数和锁策略
 * @param updateRowHandler 行数据修改回调处理器，校验并修改行数据后提交更新
 * @return 修改后的行记录集合
 */
public List updateFetch(final QueryExecutor queryExecutor, final UpdateRowHandler updateRowHandler);
```

* 使用范例（库存扣减：锁定 → 校验库存充足 → 扣减 → 返回最新数据）

```java
List result = lightDao.updateFetch(
        // 简单查询 + 悲观锁策略
        new QueryExecutor("sqltoy_stock_find")
                .names("productId").values("P0001")
                .lock(LockMode.UPGRADE),
        // 注意：UpdateRowHandler 的方法均为 default，不是函数式接口，需用匿名类覆写
        new UpdateRowHandler() {
            @Override
            public void updateRow(ResultSet rs, int index, BiConsumer<String, Object> setVal) throws Exception {
                double quantity = rs.getDouble("quantity");
                if (quantity < 1) {
                    // 逻辑校验不通过直接抛异常，本次修改整体回滚
                    throw new IllegalArgumentException("库存不足!");
                }
                // 通过反调设置修改后的值：<属性名, 新值>
                setVal.accept("quantity", quantity - 1);
            }
        });
```

> `UpdateRowHandler` 提供三个可覆写方法：`updateRow(rs,index)`、`updateRow(rs,index,BiConsumer<属性,值>)`、`updateRow(rs,index,ThreeBiConsumer<属性,强制更新字段[],值>)`（第三个可指定强制更新字段）。
>
> 与下节 `updateSaveFetch` 互补：`updateFetch` 修改**已存在**的记录；`updateSaveFetch` 锁查询后**不存在则执行 insert**。

# 10、updateSaveFetch操作

* 锁查询，存在则修改、不存在则保存，适用于类似库存台账、资金台账业务场景

```xml
//引入依赖类
<dependency>
    <groupId>net.bytebuddy</groupId>
    <artifactId>byte-buddy</artifactId>
    <version>1.18.11</version>
</dependency>
```

```java
//api 
/**
 * @TODO 适用于库存台账、客户资金账等高并发强事务场景，一次数据库交互实现：
 *       <p>
 *       <li>1、锁查询；</li>
 *       <li>2、记录存在则修改；</li>
 *       <li>3、记录不存在则执行insert；</li>
 *       <li>4、返回修改或插入的记录信息</li>
 *       </p>
 */
public <T extends Serializable> T updateSaveFetch(final T entity, final EntityUpdateCallback<T> callback,
			final String... uniqueProps);
```


```java
//示例
@Test
public void testUpdateSaveFetch() {
    StaffInfoVO staffInfo = new StaffInfoVO();
    staffInfo.setStaffId("S0001");
    staffInfo.setBeginDate(LocalDate.parse("2019-01-01"));
    staffInfo.setEndDate(LocalDate.now());
    staffInfo.setStaffName("陈");
    lightDao.updateSaveFetch(staffInfo, (entity, rowIndex) -> {
	// 这里entity取值，实际通过代理，走的是rs.getString("tel_no")获取的值
	String telNo = entity.getTelNo();
	if (telNo != null) {
		// 这里set，实际是rs.updateString("tel_no", telNo.substring(0, 3) + "#**#" +
		// telNo.substring(7));
		entity.setTelNo(telNo.substring(0, 3) + "#**#" + telNo.substring(7));
	}
    });
}
```


