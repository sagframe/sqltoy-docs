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
