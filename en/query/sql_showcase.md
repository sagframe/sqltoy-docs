# SQL Showcase

## 1. Shared SQL fragment @include(sqlId)

```xml
<sql id="showcase_1">
    <value><![CDATA[
        select * from table1 t where t.name like :name
    ]]></value>
</sql>

<sql id="showcase_2">
    <value><![CDATA[
        @include("showcase_1")
        #[and t.status=:status]
    ]]></value>
</sql>
```

## 2. Dynamic fragment @include(:scriptParam)

* A variant of @include(sqlId): the SQL fragment is passed in dynamically as a parameter.

```java
String sql="select * from sqltoy_fruit_order where status=:status @include(:sqlScript)";
List result = lightDao.find(sql,MapKit.keys("status", "saleCount", "sqlScript").values(1, 12, "and sale_count>:saleCount"));
```

## 3. Usage of @if(), @elseif(), @else

* sqltoy reserves a super-powerful usage for SQL handling in special business scenarios:

```java
@Test
public void testMultiInnerIfElse1() throws Exception {
    String sql = """
        select * from table where 1=1
        #[@if(:flag==1) and name like :name]
        #[@elseif(:flag==2)
            #[@if(:operateType==1) and status=:status]
            #[@elseif(:operateType==2) and saleType is not :saleType]
            #[@else and saleType is :saleType]
        ]
        #[@else and orderType=:orderType]
        #[@if(:tenantId==4) and tenant=1]
        #[@elseif(:tenantId==3) and tenant=3]
        """;

    SqlToyResult result = SqlConfigParseUtils.processSql(SqlUtil.clearMark(sql),
        new String[]{"flag", "status", "name", "orderType", "saleType", "operateType", "tenantId"},
        new Object[]{2, 1, "Chen", "SALE", null, 4, 3});
    System.err.println(JSON.toJSONString(result));
}

```

* The logical expressions of @if include:
+ Single condition: @if(:paramName>=value)
+ Multiple conditions: @if(:paramName1>=value1 && :paramName2<=value2)
+ Comparison operators: >, >=, ==, <, <=, !=, <>; logical operators: && and ||, include, in, out
+ Time comparison: @if(:paramName>=now()+x) or @if(:paramName>=now()-x)
+ Time expressions: now(), nowtime(), ${.now}
+ Date expressions: day(), sysdate(), ${.day}
+ include containment check: @if(:statusAry include 1) — if statusAry is an array containing 1, it returns true; if statusAry is a string, it returns the result of statusAry.contains("1").
+ exclude: @if(:statusAry exclude 1), the opposite of include, meaning "does not contain"
+ Get the size: @if(size(:statusAry)>1)), i.e. get the length of a collection/array via size(:paramName)
+ in usage: @if(:status in '1,2,3') returns true when status equals 1, 2, or 3
+ out usage: @if(:status out '1,2,3') returns true when status is none of 1, 2, or 3

## 4. Usage of @loop(), @secure-loop(), @loop-full(), @secure-loop-full()

* @loop() is used to dynamically loop-concatenate fields and conditions in SQL, generally for arrays or collections, and does not apply to in-clause scenarios.
* @secure-loop(): unlike @loop, parameters are not concatenated directly into the SQL but passed as ? placeholders, preventing SQL injection.
Three formats:

```
@secure-loop(:loopParam,loopContent)
@loop(:loopParam,loopContent) not recommended
@secure-loop(:loopParam,loopContent,linkSign)
@loop(:loopParam,loopContent,linkSign) not recommended
@secure-loop(:loopParam,loopContent,linkSign,startIndex,endIndex)
@loop(:loopParam,loopContent,linkSign,startIndex,endIndex) not recommended
```
* Example

```xml
<sql id="qstart_loop_sql">
    <value><![CDATA[
        select ORDER_ID
        @loop(:fields,",",:fields[i])
        from sqltoy_device_order t
        where #[t.ORDER_ID=:orderId]
        -- @blank(:param) exists to work with sqltoy's #[] null-elimination feature: when the value is not null, @blank() is replaced with an empty string (you can also use @if instead of @blank)
        #[@if(size(:staffIds)>0) and (@secure-loop(:staffIds," t.STAFF_ID=:staffIds[i] "," or ",1,100))]
        #[@blank(:startDates)
            and ( @loop(:startDates,
                " t.TRANS_DATE between STR_TO_DATE(':startDates[i]','%Y-%m-%d')
                and STR_TO_DATE(':endDates[i]','%Y-%m-%d') ",
            " or "))]
    ]]></value>
</sql>

```

## 5. Configuration-driven integration in sqltoy, e.g. reports and configurable API services

* sqltoy development is not purely about writing Java code; it also serves the rapid development of page-configured reports and API services. The integration mechanism:

* Use an XML fragment directly in code

```java
//sqlXml content can come from database configuration, or from a report configuration model fragment
String sqlXml="""
               <sql>
                 content omitted
               </sql>
              """;
//add parameters: new XMLBinding(sqlXml).id(id).lastUpdateTime(lastUpdateTime)
//lastUpdateTime is the last modified time of the xml; if nothing changed, the parsed model is fetched directly from cache
lightDao.findByQuery(new QueryExecutor(new XMLBinding(sqlXml).id(id).lastUpdateTime(lastUpdateTime))
                    .values(valueDTO).resultType(OrderInfoVO.class));
```

* Parse the XML fragment and register it into the sqltoy context

```java
String sqlXML=sqlElt.element("sql").getTextTrim();
//parse the xml with sqltoy's internal utility to build the sqltoy model
SqlToyConfig sqlToyConfig=lightDao.getSqlToyContext().parseSqlSegment(sqlXML);
//a report may contain multiple sql fragments, so ensure uniqueness by combining reportId+"_"+index
sqlToyConfig.setId(reportId+"_"+sqlScriptIndex);
//register the model into the sqltoy context; afterwards you can call lightDao.find(id,paramsMap)
lightDao.getSqlToyContext().putSqlToyConfig(sqlToyConfig);
```

## 6. Collecting slow-query SQL statistics

* Enable it with the default configuration

```properties
# Print the sql execution timeout threshold (milliseconds, default is 8000 ms)
#spring.sqltoy.printSqlTimeoutMillis=8000
# Set the default overtime handler, which collects timed-out sql entries
spring.sqltoy.overTimeSqlHandler= org.sagacity.sqltoy.plugins.overtime.DefaultOverTimeHandler
```

* Get slow queries via the API

```java
//size     number of records to fetch
//hasSqlId whether it is an sql defined in xml with an id (the other kind is sql written directly in code)
//public List<OverTimeSql> getSlowestSql(int size, boolean hasSqlId);

List<OverTimeSql> slowSqlList=lightDao.getSqlToyContext().getSlowestSql(10,true);
```

## 7. The database is not in the adaptation list, but it is derived from postgresql/opengaussdb — how to adapt it?

* 7.1 For a single database, specify the dialect directly

```properties
#solon.sqltoy.dialect=postgresql
spring.sqltoy.dialect=postgresql
```

* 7.2 For multi-database scenarios, map dialects via the database name obtained from conn.getMetaData().getDatabaseProductName()

```properties
#solon.sqltoy.dialectMap.oscar=opengauss
spring.sqltoy.dialectMap.oscar=opengauss
```
