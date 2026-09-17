# Cache Translate Introduction

Cache translate exists to simplify SQL logic and avoid excessive joins. Example: when querying the staff table, an employee's post, home town and skill level are data-dictionary codes that must be shown as names. Multi-value translation is supported:
a field containing `A,B,C` is translated into `Name A,Name B,Name C`.

## Main use cases

1. Reduce join queries — simpler SQL and a huge efficiency gain
2. Fetch caches directly through the API to feed business logic or the UI, avoiding a database hit every time
    e.g. front-end selects, checkboxes, suggest components and organization trees can read straight from the cache
3. Filter cache data through the API and reverse-match keys, replacing SQL LIKE queries

## Three ways to use cache translate

1. The `<translate>` tag in the sql xml
2. `QueryExecutor::translates(Translate... translates)` in findByQuery (and EntityQuery equivalents)
3. The `@Translate` annotation on DTO properties

## Create the dictionary and organization tables

SQL sample script: [translate_template.sql](https://github.com/sagframe/sqltoy-docs/blob/main/scripts/translate_template.sql)

## Configure cache translate
### Enable cache translate in sqltoy
```yml
spring:
    sqltoy:
        # defaults to classpath:sqltoy-translate.xml;classpath:translates — no config needed with default naming
        translateConfig: classpath:sqltoy-translate.xml
```
### The sqltoy-translate.xml file
```xml
<?xml version="1.0" encoding="UTF-8"?>
<sagacity
	xmlns="https://www.sagframe.com/schema/sqltoy-translate"
	xmlns:xsi="https://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="https://www.sagframe.com/schema/sqltoy-translate https://www.sagframe.com/schema/sqltoy/sqltoy-translate.xsd">
	<!-- caches expire by default after 1 hour, so only frequently-changing caches need timely checkers -->
	<cache-translates>
		<!-- cache loaded directly by a sql query -->
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
		<!-- organ id to organ name cache -->
		<sql-translate cache="organIdNameCache">
			<sql>
			<![CDATA[
				select ORGAN_ID,ORGAN_NAME from SQLTOY_ORGAN_INFO order by SHOW_INDEX
			]]>
			</sql>
		</sql-translate>
	</cache-translates>

	<!-- cache refresh checkers; multiple sql/service/rest based checkers are allowed -->
	<cache-update-checkers cluster-time-deviation="1">
		<!-- sql-based cache update checker -->
		<sql-increment-checker cache="organIdNameCache"	check-frequency="60">
			<sql><![CDATA[
			--#not_debug#--
			select ORGAN_ID,ORGAN_NAME 
			from SQLTOY_ORGAN_INFO
			where UPDATE_TIME >=:lastUpdateTime
			]]></sql>
		</sql-increment-checker>

		<!-- incremental update where the first column of the result is the inside category -->
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
## Test it
### Add 2 properties to OrderInfoVO

```java
@Data
@Accessors(chain = true)
public class OrderInfoVO implements Serializable {
	/**
	 * 
	 */
	private static final long serialVersionUID = 3853685083880883292L;
/*---begin-auto-generate-don't-update-this-area--*/	
// existing properties omitted here
/*---end-auto-generate-don't-update-this-area--*/

	// two new extended properties
	/**
	 * Organ name
	 */
	private String organName;
	
	/**
	 * Order type name
	 */
	private String orderTypeName;
}
```

### Write the test class

1. Java-code mode

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
	
	// use translates(Translate...Translates) on the QueryExecutor/EntityQuery of
	// findByQuery / findPageByQuery / findEntity / findPageEntity
	@Test
	public void testTranslate() {
		String sql = """
				select t.*,
				       -- two extra query columns mapped to the name properties of the VO
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
	// the xml equivalent:
	//<translate cache="dictKeyNameCache" cache-type="ORDER_TYPE" columns="orderTypeName"/>
	//<translate cache="organIdNameCache" columns="organName"/>
	// sql see com/sqltoy/helloworld/sqltoy/sqltoy-helloworld.sql.xml; sqlId must be globally unique
	@Test
	public void testTranslateWithSqlId() {
		List<OrderInfoVO> result = lightDao.find("helloworld_search_orderInfo",
				MapKit.keys("statusAry", "beginTime", "endTime").values(new Integer[] { 1 },
						LocalDateTime.parse("2024-10-17T00:00:01"), null),
				OrderInfoVO.class);
		System.err.println(JSON.toJSONString(result));
	}
	
	/**
	 * Annotation mode: put @Translate on the organName / orderTypeName properties of OrderInfoVO, e.g.:
	 * @Translate(cacheName = "organIdNameCache", keyField = "organId")
	 * private String organName;
	 */
	@Test
	public void testTranslateByAnnotationTrans() {
		List<OrderInfoVO> result = lightDao.findEntity(OrderInfo.class,
				// for select * there is no need to call .select(); shown here for demonstration only
				// EntityQuery.create().unselect(excludedFields)
				EntityQuery.create().select()
						// follows the sqltoy dynamic-condition rules
						.where("#[and status in (:statusAry)]#[and createTime>=:beginTime]#[and createTime<=:endTime]")
						.values(MapKit.keys("statusAry", "beginTime", "endTime").values(new Integer[] { 1 },
								LocalDateTime.parse("2024-10-17T00:00:01"), null)),
				OrderInfoVO.class);
		System.err.println(JSON.toJSONString(result));
	}
}

```

2. xml mode

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sagacity
	xmlns="http://www.sagframe.com/schema/sqltoy-translate"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://www.sagframe.com/schema/sqltoy-translate http://www.sagframe.com/schema/sqltoy/sqltoy-translate.xsd">
	<!-- caches expire by default after 1 hour, so only frequently-changing caches need timely checkers -->
	<cache-translates>
		<!-- cache loaded directly by a sql query -->
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
		<!-- organ id to organ name cache -->
		<sql-translate cache="organIdNameCache">
			<sql>
			<![CDATA[
				select ORGAN_ID,ORGAN_NAME from SQLTOY_ORGAN_INFO order by SHOW_INDEX
			]]>
			</sql>
		</sql-translate>
	</cache-translates>

	<!-- cache refresh checkers; multiple sql/service/rest based checkers are allowed -->
	<cache-update-checkers cluster-time-deviation="1">
		<!-- sql-based cache update checker -->
		<sql-increment-checker cache="organIdNameCache"	check-frequency="60">
			<sql><![CDATA[
			--#not_debug#--
			select ORGAN_ID,ORGAN_NAME 
			from SQLTOY_ORGAN_INFO
			where UPDATE_TIME >=:lastUpdateTime
			]]></sql>
		</sql-increment-checker>

		<!-- incremental update where the first column of the result is the inside category -->
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

## Other uses of the cache

* 1. Fetch a cache directly:
> lightDao.getTranslateCache("dictCache","ORDER_TYPE");  
> lightDao.getTranslateCache("organCache",null,OrganInfoVO.class);

```java
/**
 * Get a translate cache, handy for front-end select options, checkboxes, suggest components, etc.
 * @param cacheName
 * @param cacheType for data dictionaries pass the dictionary type, otherwise null
 */
public HashMap<String, Object[]> getTranslateCache(String cacheName, String cacheType);

/**
 * Fetch the cache data as objects
 * @param cacheName
 * @param cacheType  for data dictionaries pass the dictionary type, otherwise null
 * @param reusltType the sql/properties aliases defined in the cache must match the properties of resultType
 */
public <T> List<T> getTranslateCache(String cacheName, String cacheType, Class<T> reusltType);
```

* 2. Translate a collection through the cache

```java
/**
 * Translate a specific property of each row via a callback
 * @param dataSet        the data collection
 * @param cacheName      cache name
 * @param cacheType      for categorized caches (data dictionary) pass the category; for staff/organ caches pass null
 * @param cacheNameIndex defaults to 1 — the column holding the name in the cache array (name, alias, short name, full name...)
 * @param handler
 */
public void translate(Collection dataSet, String cacheName, String cacheType, Integer cacheNameIndex,
		TranslateHandler handler);
		
// usage example
lightDao.translate(staffVOs<StaffInfoVO>, "staffIdName",	1， new TranslateHandler() {
	// provide the key
	public Object getKey(Object row) {
		return ((StaffInfoVO)row).getStaffId();
	}
	// set the translated name onto the target property
	public void setName(Object row, String name) {
		((StaffInfoVO)row).setStaffName(name);
	}
});
```

* 3. Filter through the cache

```java
/**
 * Fuzzy-match names against a cache to obtain the matching keys
 * @param cacheMatchFilter
 * @param matchRegexes     array
 */
public String[] cacheMatchKeys(CacheMatchFilter cacheMatchFilter, String... matchRegexes);

// example
String[] keys = lightDao.cacheMatchKeys(CacheMatchFilter.create()
		.cacheName("organIdNameCache")
		// match on the first column (organ name); matchIndexs(1,2) would also match aliases
		.matchIndexs(1)
		// return column 0
		.cacheKeyIndex(0)
		// prefer exact matching (e.g. given "上海新能源" against "上海新能源..." and "中国上海新能源发展公司",
		// the first organ's code is returned; otherwise a LIKE-style match applies)
		.priorMatchEqual(true)
		// max number of matches
		.matchSize(2), "新能源研究院");
```

## Advanced cache-translate scenarios

### Multiple translates per field / conditional translate

The same field can have several `<translate>` tags against different caches; the `where` attribute enables **conditional translation** (translate only when the condition holds), supporting four logics: `==`, `!=`, `in`, `out`:

```xml
<!-- translate only when the order type is PO -->
<translate cache="orderTypeCache" columns="orderTypeName" where="order_type==PO" />
<!-- neq / in / out work the same way -->
<!-- <translate ... where="status!=0" /> -->
<!-- <translate ... where="order_type in (PO,SPO)" /> -->
<!-- <translate ... where="order_type out (SALES)" /> -->
```

### Split-value translation（split-sign / link-sign）

When a field holds **concatenated codes** such as `F,M`, `split-sign` splits them for individual translation and `link-sign` joins the results back:

```xml
<!-- "F,M" → translated to "Female,Male" -->
<translate cache="sexCache" columns="sexName" split-sign="," link-sign="、" />
```

### Tenant-isolated translation

In multi-tenant scenarios, `cache-type` can dynamically carry the current user's tenant id (e.g. `${user_tenant_id}`) through the common-field extension, giving a **tenant-isolated cache** (reusing the data-dictionary categorization mechanism):

```xml
<translate cache="tenantConfigCache" cache-type="${user_tenant_id}" columns="configName" />
```

### i18n translation

Add an **`i18n`** attribute to the cache definition in `sqltoy-translate.xml` (format `locale:columnIndex`, comma- or semicolon-separated, e.g. `zh_cn:1,en_us:2`) so translation picks the value from the column matching the current locale:

```xml
<!-- the cache sql must also select the per-language name columns; i18n declares the locale-to-column mapping -->
<sql-translate cache="dictCache" datasource="dataSource" i18n="zh_cn:1,en_us:2">
    <sql><![CDATA[
        select t.DICT_KEY, t.DICT_NAME, t.DICT_NAME_EN
        from SQLTOY_DICT_DETAIL t
        where t.DICT_TYPE=:dictType
    ]]></sql>
</sql-translate>
```

In code, set the current thread locale via `I18nThreadHolder` (in real projects a filter usually injects the user's locale, calling `remove()` at the end of the request):

```java
I18nThreadHolder.put("en_us");
try {
    // cache translation for this query takes the en_us column (DICT_NAME_EN)
    List result = lightDao.find("sqltoy_dict_find", paramsMap, DictInfoVO.class);
} finally {
    I18nThreadHolder.remove();
}
```
