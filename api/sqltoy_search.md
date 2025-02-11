# sqltoy查询简介
* 1、sqltoy查询支持常规查询、分页查询、取top、取随机记录、校验数据唯一性
* 2、sqltoy的查询支持xml中写sql、java代码中直接传sql和第三方提供的lambda模式插件
* 3、掌握基本规则，简单的直接用lightDao的显式接口，复杂场景用find(Page|Top)ByQuery这种类型，通过QueryExecutor或EntityQuery来组织参数,  
    显式查询接口的底层都是基于QueryExecutor,了解这个就知道灵活运用了

## sqltoy动态查询sql编写原理
* 1、sqltoy通过filters标签将mybatis中sql语句中间的if等逻辑剥离出来，从而保障了sql语句的整洁性
* 2、sqltoy的配置里面隐藏了默认的blank-to-null="true"属性
* 3、#[]表示条件片段是动态的，必要条件不用加#[]
* 4、#[and t.name like :name and t.status=:status] 逻辑就是其中只要有一个参数为null，整个片段就被剔除
* 5、#[]作用就比较单纯标记sql逻辑的开始和截至位置
* 6、#[t.type=:type #[and t.amt>:amt and t.quantity>:quantity]]支持多层嵌套
* 7、必要条件，当参数为null时会自动转is null或 is not null
* 8、#标记恰巧是mysql等数据库的注释，所以可以在客户端里面直接执行

## xml表示形态

```xml

<!-- 隐藏了blank-to-null="true" <sql id="show_case" blank-to-null="true">-->
<sql id="show_case">
<filters>
   <!-- 通过filters中的标记对条件参数做前置规整处理 -->
   <eq params="status" value="-1" />
   <!-- 要关闭blank-to-null="true"两种做法：
      1、blank-to-null="false"
      2、通过blank标签对任意一个参数(包括不存在的)做一次处理，就自动关闭了blank-to-null的默认设置
   -->
   <blank params="anyParamNameIncludeNotExist"/>
</filters>
<value><![CDATA[
	select 	*
	from sqltoy_device_order_info t 
	where 
	      -- orderType为null会自动转成t.order_type is null
	      t.order_type=:orderType
	      and t.ORGAN_ID in (:authedOrganIds)
	      #[and t.status=:status]
	      #[and t.ORDER_ID=:orderId]
	      #[and t.TRANS_DATE>=:beginAndEndDate[0]]
	      #[and t.TRANS_DATE<:beginAndEndDate[1]]  
          #[and (t.TECH_GROUP,t.PROD_GROUP) in (:techGroups,:prodGroups)]
	]]></value>
</sql>

```

## java代码表示形态(xml能做的代码中也可以)

```java
String whereString = """
		   orderType=:orderType
		   and organId in (:authedOrganIds)
		   #[and status=:status]
		   #[and orderId=:orderId]
		   #[and transDate>=:beginAndEndDate[0]]
		   #[and transDate<:beginAndEndDate[1]]
		   #[and (techGroup,prodGrou) in (:techGroups,:prodGroups)]
		""";
List result = lightDao.findEntity(DeviceOrderVO.class, EntityQuery.create()
			// .blankNotNull()
			.where(whereString)
			.values(MapKit.keys("orderType", "authedOrganIds", "status", "orderId", "transDate").values("PO",
					authedOrganIds, "1", "S0001", beginAndEndTime))
			.filters(new ParamsFilter("status").eq("-1")));
```

## 查询单条记录
* api接口说明  
  1、单条记录查询，都以load开头或findOne  
  2、查询结果记录数量必须是<=1,大于1条会报错

```java
/**
 * @TODO 通过map传参模式获取单条对象记录
 * @param <T>
 * @param sqlOrSqlId 可以直接传sql语句，也可以是xml中定义的sql id
 * @param paramsMap
 * @param resultType 可以是vo、dto、Map(默认驼峰命名)
 * @return
 */
public <T> T findOne(final String sqlOrSqlId, final Map<String, Object> paramsMap, final Class<T> resultType);

/**
 * @todo 通过对象实体传参数,框架结合sql中的参数名称来映射对象属性取值
 * @param sqlOrSqlId
 * @param entity
 * @param resultType
 * @return
 */
public <T> T findOne(final String sqlOrSqlId, final Serializable entity, final Class<T> resultType);

/**
 * @TODO 根据QueryExecutor来链式操作灵活定义查询sql、条件、数据源等
 * @param query new QueryExecutor(sql).dataSource().names().values().filters()
 *              链式设置查询
 * @return
 */
public Object loadByQuery(final QueryExecutor query);

/**
 * @TODO 通过EntityQuery模式加载单条记录
 * @param <T>
 * @param entityClass
 * @param entityQuery 例如:EntityQuery.create().select(a,b,c).where("tenantId=?
 *                    and staffId=?).values("1","S0001")
 * @return
 */
public <T extends Serializable> T loadEntity(Class<T> entityClass, EntityQuery entityQuery);

public <T extends Serializable> T loadEntity(Class entityClass, EntityQuery entityQuery, Class<T> resultType);
```

* 使用范例

```java
//简单模式
lightDao.findOne("select * from order_info where order_id=:orderId",MapKit.map("orderId","S0001"),OrderInfo.class);

//指定数据库
lightDao.loadByQuery(new QueryExecutor("select * from order_info where order_id=:orderId")
       .dataSource(xxxDataSource).names("orderId").values("S0001").resultType(OrderInfo.class));
       
//注意:这里可以再次指定resultType，如果不指定就返回OrderInfo.class类型
lightDao.loadEntity(OrderInfo.class,EntityQuery.create().select(a,b,c).where("orderId=?").values("S0001").resultType(OrderInfoVO.class));
```

## 获取单值

* api说明

```java
public Object getValue(final String sqlOrSqlId, final Map<String, Object> paramsMap);

/**
 * @TODO 获取查询结果的第一条、第一列的值，一般用select max(x) from 等
 *      <li>lightDao.getValue("select max(amt) from table",null,BigDecimal.class)</li>
 * @param <T>
 * @param sqlOrSqlId
 * @param paramsMap
 * @param resultType
 * @return
 */
public <T> T getValue(final String sqlOrSqlId, final Map<String, Object> paramsMap, final Class<T> resultType);
```