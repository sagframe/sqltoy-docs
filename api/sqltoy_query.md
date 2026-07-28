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

#### 存储过程调用

* api
```
/**
 * @todo 存储过程调用
 * @param storeSqlOrKey 可以是xml中的sqlId 或者直接{call storeName (?,?)}
 * @param inParamValues
 * @return StoreResult 用:getRows()获得查询结果
 */
public StoreResult executeStore(final String storeSqlOrKey, final Object[] inParamValues);

/**
 * @TODO 存储过程调用，outParams可以为null
 * @param storeSqlOrKey 可以是xml中的sqlId 或者直接{call storeName (?,?)}
 * @param inParamValues
 * @param outParamsType 可以为null
 * @param resultType    可以是VO、Map.class、LinkedHashMap.class、Array.class,null(二维List)
 * @return StoreResult 用:getRows()获得查询结果
 */
public StoreResult executeStore(String storeSqlOrKey, Object[] inParamValues, Integer[] outParamsType,
		Class resultType);
```

* 调用示例

```java
//无结果调用
lightDao.executeStore("{call storeName(?,?)}", new Object[]{value1,value2});

//存储过程查询
List result=lightDao.executeStore("{call storeName(:param1,:param2)}",MapKit.keys("param1","param2").values(value1,value2),VO.class).getRows();
```

* 多集合存储过程

```java
/**
 * @TODO 存储过程调用，outParams可以为null
 * @param storeSqlOrKey 可以是xml中的sqlId 或者直接{call storeName (?,?)}
 * @param inParamValues
 * @param outParamsType 可以为null
 * @param resultTypes   可以是VO、Map.class、LinkedHashMap.class、Array.class,null(二维List)
 * @return StoreResult 用:getRows()获取主记录、List[] getMoreResults()获取全部结果
 */
public StoreResult executeMoreResultStore(String storeSqlOrKey, Object[] inParamValues, Integer[] outParamsType,
		Class... resultTypes);
```


