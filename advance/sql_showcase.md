# sqltoy使用场景案例

## 1.公共sql片段@include(sqlId)

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

## 2.动态片段@include(:scriptParam)

* @include(sqlId)的一种变种，通过动态传参形式传入sql片段

```java
String sql="select * from sqltoy_fruit_order where status=:status @include(:sqlScript)";
List result = lightDao.find(sql,MapKit.keys("status", "saleCount", "sqlScript").values(1, 12, "and sale_count>:saleCount"));
```

## 3. @if()、@elseif()、@else用法
* Sqltoy针对一些特殊业务场景给sql处理预留一个超级用法:

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
        new Object[]{2, 1, "陈", "SALE", null, 4, 3});
    System.err.println(JSON.toJSONString(result));
}

```

* @if的逻辑表达式包含:
+ 单逻辑判断:@if(:paramName>=value)
+ 多逻辑判断:@if(:paramName1>=value1 && :paramName2<=value2)
+ 比较符号支持:>、>=、==、<、<=、!=、<>;逻辑运算符:&& 和 ||、include、in、out
+ 时间比较:@if(:paramName>=now()+x) 或@if(:paramName>=now()-x)
+ 表示时间的:now()、nowtime()、${.now}
+ 表示日期的:day()、sysdate()、${.day}
+ include包含判断：@if(:statusAry include 1),如果statusAry是数组其中包含1返回true，如果statusAry值是一个字符串，返回statusAry. contains(“1”) 的结果。
+ exclude @if(:statusAry exclude 1) ,跟include相反，不包含的意思
+ 取size:@if(size(:statusAry)>1)) ,即通过size(:参数名称)模式取得集合数组的长度
+ In 用法: @if(:status in  ‘1,2,3’) 当status属于1或2或3时返回true 
+ out 用法:@if(:status out ‘1,2,3’) 当status不属于1或2或3时返回true

## 4. @loop()、@secure-loop()、@loop-full()、@secure-loop-full()的用法

* @loop()用于sql动态循环拼接字段、条件，一般针对数组或集合，且不适用于in的场景。
* @secure-loop():跟@loop的区别在于参数不会直接拼接到sql中，而是采用?形式入参，防止sql注入
分三种格式

```
@secure-loop(:loopParam,loopContent)
@loop(:loopParam,loopContent) 不推荐
@secure-loop(:loopParam,loopContent,linkSign)
@loop(:loopParam,loopContent,linkSign) 不推荐
@secure-loop(:loopParam,loopContent,linkSign,startIndex,endIndex)
@loop(:loopParam,loopContent,linkSign,startIndex,endIndex) 不推荐
```
* 示例

```xml
<sql id="qstart_loop_sql">
    <value><![CDATA[
        select ORDER_ID
        @loop(:fields,",",:fields[i])
        from sqltoy_device_order t
        where #[t.ORDER_ID=:orderId]
        -- @blank(:param) 目的是迎合sqltoy #[] 中参数为null剔除的功能，当值不为null时@blank()被替代为空白字符串(当然也可以用@if来代替@blank)
        #[@if(size(:staffIds)>0) and (@secure-loop(:staffIds," t.STAFF_ID=:staffIds[i] "," or ",1,100))]
        #[@blank(:startDates)
            and ( @loop(:startDates,
                " t.TRANS_DATE between STR_TO_DATE(':startDates[i]','%Y-%m-%d')
                and STR_TO_DATE(':endDates[i]','%Y-%m-%d') ",
            " or "))]
    ]]></value>
</sql>

```

## 5. sqlToy实现配置化集成，如报表、配置化api服务等
* sqltoy的开发并非存粹基于写java代码模式，同时也服务于快速页面配置化报表、接口服务的开发，具体集成机制

* 代码中直接使用xml片段

```java
//sqlXml内容可以基于数据库配置，或报表配置模型片段
String sqlXml="""
               <sql>
                 内容省略
               </sql>
              """;
//新增参数：new XMLBinding(sqlXml).id(id).lastUpdateTime(lastUpdateTime)
//lastUpdateTime 指xml最后修改时间，如果没有变化则从缓存直接获取xml解析后的模型
lightDao.findByQuery(new QueryExecutor(new XMLBinding(sqlXml).id(id).lastUpdateTime(lastUpdateTime))
                    .values(valueDTO).resultType(OrderInfoVO.class));
```

* 解析xml片段注册到sqltoy上下文

```java
String sqlXML=sqlElt.element("sql").getTextTrim();
//结合sqltoy内部工具解析xml形成sqltoy模型
SqlToyConfig sqlToyConfig=lightDao.getSqlToyContext().parseSqlSegment(sqlXML);
//这里考虑一张报表里面存在多个sql片段，确保唯一，用reportId+"_"+index 组合
sqlToyConfig.setId(reportId+"_"+sqlScriptIndex);
//将模型注册到sqltoy上下文，后续就可以lightDao.find(id,paramsMap)调用了
lightDao.getSqlToyContext().putSqlToyConfig(sqlToyConfig);
```




