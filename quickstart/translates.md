# 缓存翻译主要使用场景
* 1、减少join联表查询,简化sql并极大提升查询效率
* 2、通过API直接获取缓存，为业务逻辑直接提供数据,避免每次查询数据库，从而提升效率  
    比如:前端select、checkbox、suggest组件、机构树等就可以直接从缓存获取数据
* 3、通过API对缓存数据进行过滤,反向匹配key,用来替代sql like查询

# 缓存翻译三种方式
* 1、基于xml的translate标记
* 2、通过findByQuery中QueryExecutor::translates(Translate...translates)
* 3、通过DTO属性上加@Translate注解

# 创建数据字典、机构表

```sql
create table SQLTOY_DICT_DETAIL
(
   DICT_KEY             varchar(50) not null  comment '字典KEY',
   DICT_TYPE            varchar(50) not null  comment '字典类型代码',
   DICT_NAME            varchar(200) not null  comment '字典值',
   SHOW_INDEX           numeric(8) not null default 1  comment '显示顺序',
   UPDATE_BY            varchar(22) not null  comment '最后修改人',
   UPDATE_TIME          datetime not null  comment '最后修改时间',
   STATUS               decimal(1) not null default 1  comment '状态',
   primary key (DICT_KEY, DICT_TYPE)
);

alter table SQLTOY_DICT_DETAIL comment '字典明细表';

create table SQLTOY_DICT_TYPE
(
   DICT_TYPE            varchar(50) not null  comment '字典类型代码',
   DICT_TYPE_NAME       varchar(100) not null  comment '字典类型名称',
   COMMENTS             varchar(500)  comment '说明',
   SHOW_INDEX           numeric(8) not null default 1  comment '显示顺序',
   CREATE_BY            varchar(22) not null  comment '创建人',
   CREATE_TIME          datetime not null  comment '创建时间',
   UPDATE_BY            varchar(22) not null  comment '最后修改人',
   UPDATE_TIME          datetime not null  comment '最后修改时间',
   STATUS               decimal(1) not null default 1  comment '状态',
   primary key (DICT_TYPE)
);

alter table SQLTOY_DICT_TYPE comment '字典分类表';

create table SQLTOY_ORGAN_INFO
(
   ORGAN_ID             varchar(22) not null  comment '机构ID',
   ORGAN_NAME           varchar(100) not null  comment '机构名称',
   ORGAN_CODE           varchar(20) not null  comment '机构代码',
   COST_NO              varchar(20)  comment '成本中心代码',
   ORGAN_PID            varchar(22) not null  comment '父机构ID',
   NODE_ROUTE           varchar(200)  comment '节点路径',
   NODE_LEVEL           numeric(1)  comment '节点等级',
   IS_LEAF              numeric(1)  comment '是否叶子节点',
   SHOW_INDEX           numeric(8) not null default 1  comment '显示顺序',
   CREATE_BY            varchar(22) not null  comment '创建人',
   CREATE_TIME          datetime not null  comment '创建时间',
   UPDATE_BY            varchar(22) not null  comment '最后修改人',
   UPDATE_TIME          datetime not null  comment '最后修改时间',
   STATUS               decimal(1) not null default 1  comment '状态',
   primary key (ORGAN_ID)
);

alter table SQLTOY_ORGAN_INFO comment '机构信息表';

INSERT INTO SQLTOY_DICT_TYPE
(`DICT_TYPE`, `DICT_TYPE_NAME`, `COMMENTS`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('ORDER_TYPE', '订单类型', '订单类型', 3, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);

INSERT INTO SQLTOY_DICT_DETAIL
(`DICT_KEY`, `DICT_TYPE`, `DICT_NAME`, `SHOW_INDEX`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('PO', 'ORDER_TYPE', '采购订单', 1, 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_DICT_DETAIL
(`DICT_KEY`, `DICT_TYPE`, `DICT_NAME`, `SHOW_INDEX`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('SO', 'ORDER_TYPE', '销售订单', 2, 'S0001', '2025-02-05 16:47:01.000', 1);

INSERT INTO SQLTOY_ORGAN_INFO 
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100001', 'X科技创新集团有限公司', '100001', NULL, '-1', '-1,100001,', 1, 0, 1, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100002', '总经理办公室', '100002', NULL, '100001', '-1,100001,100002,', 2, 1, 2, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100003', '人力资源部', '100003', NULL, '100001', '-1,100001,100003,', 2, 1, 3, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100004', '财务部', '100004', NULL, '100001', '-1,100001,100004,', 2, 1, 4, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100005', '生物医药研发中心', '100005', NULL, '100001', '-1,100001,100005,', 2, 1, 5, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100006', '智能设备研发中心', '100006', NULL, '100001', '-1,100001,100006,', 2, 1, 6, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100007', '信息化研发中心', '100007', NULL, '100001', '-1,100001,100007,', 2, 1, 7, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100008', '新动力研发中心', '100008', NULL, '100001', '-1,100001,100008,', 2, 0, 8, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100009', '新能源研究院', '100009', NULL, '100008', '-1,100001,100008,100009,', 3, 1, 9, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100010', '发动机研究院', '100010', NULL, '100008', '-1,100001,100008,100010,', 3, 1, 10, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100011', '后勤保障部', '100011', NULL, '100001', '-1,100001,100011,', 2, 1, 11, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);

```

# 配置缓存翻译
## sqltoy增加缓存翻译的配置
```yml
spring:
    sqltoy:
        #默认classpath:sqltoy-translate.xml;classpath:translates,按默认命名则无需配置
        translateConfig: classpath:sqltoy-translate.xml
```
## sqltoy-translate.xml配置
```xml
<?xml version="1.0" encoding="UTF-8"?>
<sagacity
	xmlns="https://www.sagframe.com/schema/sqltoy-translate"
	xmlns:xsi="https://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="https://www.sagframe.com/schema/sqltoy-translate https://www.sagframe.com/schema/sqltoy/sqltoy-translate.xsd">
	<!-- 缓存有默认失效时间，默认为1小时,因此只有较为频繁的缓存才需要及时检测 -->
	<cache-translates>
		<!-- 基于sql直接查询的方式获取缓存 -->
		<sql-translate cache="dictKeyNameCache">
			<sql>
			<![CDATA[
				select t.DICT_KEY,t.DICT_NAME,t.STATUS
				from SQLTOY_DICT_DETAIL t
		        where t.DICT_TYPE=:dictType
		        order by t.SHOW_INDEX
			]]>
			</sql>
		</sql-translate>
		<!-- 机构号和机构名称的缓存 -->
		<sql-translate cache="organIdNameCache">
			<sql>
			<![CDATA[
				select ORGAN_ID,ORGAN_NAME from SQLTOY_ORGAN_INFO order by SHOW_INDEX
			]]>
			</sql>
		</sql-translate>
	</cache-translates>

	<!-- 缓存刷新检测,可以提供多个基于sql、service、rest服务检测 -->
	<cache-update-checkers cluster-time-deviation="1">
		<!-- 基于sql的缓存更新检测 -->
		<sql-increment-checker cache="organIdNameCache"	check-frequency="60">
			<sql><![CDATA[
			--#not_debug#--
			select ORGAN_ID,ORGAN_NAME 
			from SQLTOY_ORGAN_INFO
			where UPDATE_TIME >=:lastUpdateTime
			]]></sql>
		</sql-increment-checker>

		<!-- 增量更新，带有内部分类的查询结果第一列是分类 -->
		<sql-increment-checker cache="dictKeyNameCache"	check-frequency="15" has-inside-group="true">
			<sql><![CDATA[
			--#not_debug#--
			select t.DICT_TYPE,t.DICT_KEY,t.DICT_NAME,t.STATUS
			from SQLTOY_DICT_DETAIL t
	        where t.UPDATE_TIME >=:lastUpdateTime
			]]></sql>
		</sql-increment-checker>
	</cache-update-checkers>
</sagacity>
```
# 测试验证
## 类OrderInfoVO增加2个属性

```java
@Data
@Accessors(chain = true)
public class OrderInfoVO implements Serializable {
	/**
	 * 
	 */
	private static final long serialVersionUID = 3853685083880883292L;
/*---begin-auto-generate-don't-update-this-area--*/	
// 中间属性这里省略
/*---end-auto-generate-don't-update-this-area--*/

	//新扩展的2个属性
	/**
	 * 机构名称
	 */
	private String organName;
	
	/**
	 * 订单类别名称
	 */
	private String orderTypeName;
}
```

## 编写测试类

```java
package com.sqltoy.helloworld.service;

import java.time.LocalDateTime;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.sagacity.sqltoy.config.model.Translate;
import org.sagacity.sqltoy.dao.LightDao;
import org.sagacity.sqltoy.model.MapKit;
import org.sagacity.sqltoy.model.QueryExecutor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import com.alibaba.fastjson2.JSON;
import com.sqltoy.helloworld.dto.OrderInfoVO;

@SpringBootTest
public class TranslateTest {
	@Autowired
	LightDao lightDao;
	
	//基于findByQuery/findPageByQuery/findEntity/findPageEntity 中
	//的QueryExecutor或EntityQuery使用translates(Translate...Translates)
	@Test
	public void testTranslate() {
		String sql = """
				select t.*,
				       -- 额外扩展两个查询属性，用于映射到VO的名称属性上
				       t.order_type orderTypeName,
				       t.organ_id organName
				from SQLTOY_ORDER_INFO t
				where 1=1
				#[and t.status in (:statusAry)]
				#[and t.create_time>=:beginTime]
				#[and t.create_time<=:endTime]
				""";
		List<OrderInfoVO> result = lightDao.findByQuery(new QueryExecutor(sql)
				.translates(new Translate("dictKeyNameCache").setCacheType("ORDER_TYPE").setColumn("orderTypeName"),
						new Translate("organIdNameCache").setColumn("organName"))
				.values(MapKit.keys("statusAry", "beginTime", "endTime").values(new Integer[] { 1 },
						LocalDateTime.parse("2024-10-17T00:00:01"), null))
				.resultType(OrderInfoVO.class)).getRows();
		System.err.println(JSON.toJSONString(result));
	}
	//xml中的
	//<translate cache="dictKeyNameCache" cache-type="ORDER_TYPE" columns="orderTypeName"/>
	//<translate cache="organIdNameCache" columns="organName"/>
	// sql参见com/sqltoy/helloworld/sqltoy/sqltoy-helloworld.sql.xml 文件,sqlId要全局唯一
	@Test
	public void testTranslateWithSqlId() {
		List<OrderInfoVO> result = lightDao.find("helloworld_search_orderInfo",
				MapKit.keys("statusAry", "beginTime", "endTime").values(new Integer[] { 1 },
						LocalDateTime.parse("2024-10-17T00:00:01"), null),
				OrderInfoVO.class);
		System.err.println(JSON.toJSONString(result));
	}
	
	/**
	 * 在OrderInfoVO属性:organName、orderTypeName上加注解模式实现缓存翻译 如:
	 * @Translate(cacheName = "organIdNameCache", keyField = "organId")
	 * private String organName;
	 */
	@Test
	public void testTranslateByAnnotationTrans() {
		List<OrderInfoVO> result = lightDao.findEntity(OrderInfo.class,
				// select * 场景无需写.select()这里仅仅示范一下
				// EntityQuery.create().unselect(排除的字段)
				EntityQuery.create().select()
						// 沿用sqltoy动态条件的规则
						.where("#[and status in (:statusAry)]#[and createTime>=:beginTime]#[and createTime<=:endTime]")
						.values(MapKit.keys("statusAry", "beginTime", "endTime").values(new Integer[] { 1 },
								LocalDateTime.parse("2024-10-17T00:00:01"), null)),
				OrderInfoVO.class);
		System.err.println(JSON.toJSONString(result));
	}
}

```

# 缓存的其他用法

* 1、直接获取缓存:  
  1)lightDao.getTranslateCache("dictCache","ORDER_TYPE");  
  2)lightDao.getTranslateCache("organCache",null,OrganInfoVO.class);

```java
/**
 * @todo 获取sqltoy中用于翻译的缓存,方便用于页面下拉框选项、checkbox选项、suggest组件等
 * @param cacheName
 * @param cacheType 如是数据字典,则传入字典类型否则为null即可
 * @return
 */
public HashMap<String, Object[]> getTranslateCache(String cacheName, String cacheType);

/**
 * @TODO 将缓存数据以对象形式获取
 * @param <T>
 * @param cacheName
 * @param cacheType  如是数据字典,则传入字典类型否则为null即可
 * @param reusltType 缓存定义时的sql属性名称或自定义的properties属性要跟resultType的属性对应
 * @return
 */
public <T> List<T> getTranslateCache(String cacheName, String cacheType, Class<T> reusltType);
```

* 2、调用缓存对集合进行翻译

```java
/**
 * @todo 对数据集合通过反调函数对具体属性进行翻译
 * @param dataSet        数据集合
 * @param cacheName      缓存名称
 * @param cacheType      例如数据字典存在分类的缓存填写字典分类，其它的如员工、机构等填null
 * @param cacheNameIndex 默认为1，缓存名称在缓存数组的第几列(因为有:名称、别名、简称、全称之说)
 * @param handler
 */
public void translate(Collection dataSet, String cacheName, String cacheType, Integer cacheNameIndex,
		TranslateHandler handler);
		
//用法示例
lightDao.translate(staffVOs<StaffInfoVO>, "staffIdName",	1， new TranslateHandler() {
	//告知key值
	public Object getKey(Object row) {
		return ((StaffInfoVO)row).getStaffId();
	}
	// 将翻译后的名称值设置到对应的属性上
	public void setName(Object row, String name) {
		((StaffInfoVO)row).setStaffName(name);
	}
});
```

* 3、调用缓存进行过滤

```java
/**
 * @TODO 通过缓存将名称进行模糊匹配取得key的集合
 * @param cacheMatchFilter
 * @param matchRegexes     数组
 * @return
 */
public String[] cacheMatchKeys(CacheMatchFilter cacheMatchFilter, String... matchRegexes);

//示例
String[] keys = lightDao.cacheMatchKeys(CacheMatchFilter.create()
		.cacheName("organIdNameCache")
		//对第一列机构名称进行匹配，可以matchIndexs(1,2) 机构名称、别称
		.matchIndexs(1)
		//设置返回列为第0列
		.cacheKeyIndex(0)
		//优先以equal方式进行匹配(如有：上海新能源\ 中国上海新能源发展公司，传入:上海新能源 就返回第一个的机构代码，否则就以like形式匹配)
		.priorMatchEqual(true)
		//匹配结果数量
		.matchSize(2), "新能源研究院");
```
