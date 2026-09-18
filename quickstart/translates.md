# 缓存翻译介绍

缓存翻译的目的在于简化sql逻辑，避免sql过多的关联，比如：查询员工信息表，员工的岗位、籍贯、技能等级等属于数据字典，要显示相应的中文。支持对多值进行翻译。
如:某个字段结构是A,B,C这种格式，翻译结果为:A名称,B名称,C名称

## 缓存翻译主要使用场景
1. 减少join联表查询,简化sql并极大提升查询效率
2. 通过API直接获取缓存，为业务逻辑直接提供数据,避免每次查询数据库，从而提升效率  
    比如:前端select、checkbox、suggest组件、机构树等就可以直接从缓存获取数据
3. 通过API对缓存数据进行过滤,反向匹配key,用来替代sql like查询

## 缓存翻译三种方式
1. 基于xml的translate标记
2. 通过findByQuery中QueryExecutor::translates(Translate...translates)
3. 通过DTO属性上加@Translate注解

## 创建数据字典、机构表

SQL示例脚本[translate_template.sql](https://github.com/sagframe/sqltoy-docs/blob/main/scripts/translate_template.sql)

## 配置缓存翻译
### sqltoy增加缓存翻译的配置
```yml
spring:
    sqltoy:
        #默认classpath:sqltoy-translate.xml;classpath:translates,按默认命名则无需配置
        translateConfig: classpath:sqltoy-translate.xml
```
### sqltoy-translate.xml配置
```xml
<?xml version="1.0" encoding="UTF-8"?>
<sagacity
	xmlns="https://www.sagframe.com/schema/sqltoy-translate"
	xmlns:xsi="https://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="https://www.sagframe.com/schema/sqltoy-translate https://sagframe.github.io/schema/sqltoy-translate.xsd">
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

> [!TIP]
> 上面的缓存都是**全量加载**模式。如果数据量达到百万级以上（如平台型电商 SKU、号码归属地），请使用[超大规模主数据缓存（FIFO）](../translate/sqltoy_FIFO_translate.md)：缓存不做全量加载，翻译时未命中的 key 动态批量获取，本地仅保留最常用的数据。

## 测试验证
### 类OrderInfoVO增加2个属性

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

### 编写测试类

1. Java代码模式

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

2. xml模式

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sagacity
	xmlns="http://www.sagframe.com/schema/sqltoy-translate"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://www.sagframe.com/schema/sqltoy-translate https://sagframe.github.io/schema/sqltoy-translate.xsd">
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

## 缓存的其他用法

* 1、直接获取缓存:  
> lightDao.getTranslateCache("dictCache","ORDER_TYPE");  
> lightDao.getTranslateCache("organCache",null,OrganInfoVO.class);

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

## 缓存翻译的附加场景

### 一个字段多次翻译 / 逻辑条件翻译

同一个字段可以配置多个 `<translate>` 按不同缓存翻译；配合 `where` 属性可做**逻辑条件翻译**（条件成立才翻译），支持四种逻辑：`==`、`!=`、`in`、`out`：

```xml
<!-- 仅当订单类型为 PO 时才翻译 -->
<translate cache="orderTypeCache" columns="orderTypeName" where="order_type==PO" />
<!-- 不等于 / in / out 同理 -->
<!-- <translate ... where="status!=0" /> -->
<!-- <translate ... where="order_type in (PO,SPO)" /> -->
<!-- <translate ... where="order_type out (SALES)" /> -->
```

### 多值拆分翻译（split-sign / link-sign）

字段值为 `F,M` 这类**多代码拼接**时，通过 `split-sign` 指定分隔符逐个翻译，再用 `link-sign` 重新拼接：

```xml
<!-- "F,M" → 翻译后 "女,男" -->
<translate cache="sexCache" columns="sexName" split-sign="," link-sign="、" />
```

### 租户隔离翻译

多租户场景下，`cache-type` 可结合公共字段扩展动态传入当前用户所属租户 ID（形如 `${user_tenant_id}`），实现**按租户隔离的缓存**（复用数据字典缓存的分类机制）：

```xml
<translate cache="tenantConfigCache" cache-type="${user_tenant_id}" columns="configName" />
```

### i18n 国际化翻译

在 `sqltoy-translate.xml` 的缓存定义上增加 **`i18n`** 属性（格式 `语言:列序号`，逗号或分号分隔，如 `zh_cn:1,en_us:2`），即可让翻译按当前语言取对应列的值：

```xml
<!-- 缓存 sql 需同时查出各语言的名称列，i18n 声明语言与列的对应 -->
<sql-translate cache="dictCache" datasource="dataSource" i18n="zh_cn:1,en_us:2">
    <sql><![CDATA[
        select t.DICT_KEY, t.DICT_NAME, t.DICT_NAME_EN
        from SQLTOY_DICT_DETAIL t
        where t.DICT_TYPE=:dictType
    ]]></sql>
</sql-translate>
```

代码中通过 `I18nThreadHolder` 设置当前线程语言（实际项目一般通过 filter 统一注入用户的 locale，请求结束时 `remove()`）：

```java
I18nThreadHolder.put("en_us");
try {
    // 此次查询的缓存翻译将取 en_us 对应列(DICT_NAME_EN)的值
    List result = lightDao.find("sqltoy_dict_find", paramsMap, DictInfoVO.class);
} finally {
    I18nThreadHolder.remove();
}
```
