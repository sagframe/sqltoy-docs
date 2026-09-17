# MongoDB 支持

**说明**：sqltoy 集成 MongoDB **只支持查询**，纯 CRUD（增删改）请直接使用 spring-data 的 `MongoTemplate`。sqltoy 集成 mongo 的出发点是：

1. 充分发挥 sqltoy **动态条件组织**的优势；
2. 结合 sqltoy 的**缓存翻译**，解决 mongo 关联配置表的复杂性（或 ETL 清洗的复杂性）；
3. 利用 sqltoy 提供的**结果集算法**（脱敏、格式化、旋转、分组汇总等），简化直接写查询/聚合的复杂度；
4. 便于与外部低代码框架（如报表平台）集成，实现配置化数据查询与处理。

> 演示项目：https://gitee.com/sagacity/sqltoy-showcase/tree/master/trunk/sqltoy-nosql

## 一、配置

sqltoy 复用 spring-data-mongodb 的 `MongoTemplate`，按 Spring Boot 标准方式配置即可：

```yaml
spring:
  data:
    mongodb:
      host: 192.168.56.101
      port: 27017
      database: sagframe
      username: sagframe
      password: sagframe
```

对象直接操作（`@Document(collection="")`、`@Id`、`@Field` 注解 + `MongoTemplate`）属于 spring-data 范畴，这里不展开；sqltoy 主要负责**查询 + 缓存翻译 + 结果集算法**。

## 二、编写 mql 查询

Mongo 查询用 `<mql>` 标签定义，`value` 中写 mongo 的 JSON 查询/聚合语句，动态条件用 `<#> ... </#>` 包裹、参数用 `@(:paramName)` 引用。

### 2.1 基本查询（字段别名 + 缓存翻译 + 脱敏）

```xml
<!-- fields 中 transType:transTypeName 表示把 transType 的值另起别名 transTypeName 存放，便于缓存翻译映射 -->
<mql id="sqltoy_mongo_find"
     fields="transId,merchantCode,transCode,transCode:transCodeName,transDate,agentOrg,transType,transType:transTypeName,transAmt"
     collection="fact_trans_details">
    <!-- 对别名列进行翻译，original-columns 指向作为代码来源的列 -->
    <!-- mongo 不能像 sql 那样 select trans_type as transTypeName，故用 fields 别名 + original-columns 实现 -->
    <translate cache="dictKeyName" cache-type="TRANS_CODE"
               columns="transCodeName" original-columns="transCode" />
    <translate cache="dictKeyName" cache-type="TRANS_TYPE"
               columns="transTypeName" original-columns="transType" />
    <!-- 安全脱敏 -->
    <secure-mask columns="merchantCode" type="bank-card" />
    <value><![CDATA[
        {
        <#>transType:@(:transType)</#>
        <#>@if(@(:flag)==1),transAmt:{$gt:@(:transAmt)}</#>
        <#>@else ,transAmt:{$gte:@(:transAmt)}</#>
        }
    ]]></value>
</mql>
```

要点：

- **字段别名**：mongo 无法像 SQL 那样 `select trans_type as transTypeName`，sqltoy 用 `fields` 中的 `源字段:别名` 语法把同一字段值复制到别名列，再用 `<translate original-columns="源字段" columns="别名">` 对别名列做缓存翻译，原代码列保持不变。
- **动态条件**：`<#>...</#>` 内参数为 null 时整段剔除；可配合 `@if()/@else` 做分支（见[补充说明：标签与表达式参考](../appendix/tags.md)）。
- **脱敏**：`<secure-mask>` 与 SQL 查询用法一致。

### 2.2 聚合查询

```xml
<!-- 聚合时 fields 可用 _id.xxx:别名 提取嵌套字段，如 group 多字段：fields="_id[transCode,colName:aliasName],count,totalAmt" -->
<mql id="sqltoy_mongo_agg"
     fields="_id.transCode:transCode,count,totalAmt"
     collection="fact_trans_details">
    <translate cache="dictKeyName" cache-type="TRANS_CODE" columns="transCode" />
    <value><![CDATA[
        [
         { $group: {
              _id: {transCode:"$transCode"},
              count: { $sum: 1 },
              totalAmt:{$sum:"$transAmt"}
           }
         },
         { $match: {
              <#>transType:@(:transType)</#>
              <#>,transAmt:{$gt:@(:transAmt)}</#>
           }
         }
        ]
    ]]></value>
</mql>
```

`value` 为聚合管道数组（`$group`/`$match`/`$sort` 等），`fields` 用 `_id.transCode:transCode` 把聚合结果中的嵌套 `_id.transCode` 提取为 `transCode` 列，再对其做缓存翻译。

### 2.3 mql 标签属性

| 属性 | 必填 | 说明 |
| --- | --- | --- |
| `id` | 是 | 查询唯一标识 |
| `collection` | 是 | mongo 集合名 |
| `fields` | 是 | 需要提取/映射的字段，支持 `源:别名`、`_id.xxx:别名`、`_id[a,b:别名]` 等写法 |
| `aggregate` | 否 | 是否聚合查询，默认 `false` |
| `blank-to-null` | 否 | 空白参数转 null |

`<mql>` 内同样支持 `filters`、`translate`、`secure-mask`、`pivot`/`unpivot`/`summary`、`page-optimize` 等子标签。

## 三、缓存翻译定义

上例中的 `dictKeyName` 缓存在 `sqltoy-translate.xml` 中定义（带内部分类 `cache-type`，即 `DICT_TYPE`）：

```xml
<sagacity xmlns="http://www.sagframe.com/schema/sqltoy-translate">
    <cache-translates>
        <!-- 基于 sql 查询获取缓存；查询结果第一列为分类(DICT_TYPE) -->
        <sql-translate cache="dictKeyName" datasource="dataSource">
            <sql><![CDATA[
                select t.DICT_KEY,t.DICT_NAME,t.STATUS
                from SQLTOY_DICT_DETAIL t
                where t.DICT_TYPE=:dictType
                order by t.SHOW_INDEX
            ]]></sql>
        </sql-translate>
    </cache-translates>
    <cache-update-checkers>
        <!-- 增量刷新检测，has-inside-group=true 表示结果第一列是分类 -->
        <sql-increment-checker cache="dictKeyName" check-frequency="15"
                               has-inside-group="true" datasource="dataSource">
            <sql><![CDATA[
                select t.DICT_TYPE,t.DICT_KEY,t.DICT_NAME,t.STATUS
                from SQLTOY_DICT_DETAIL t
                where t.UPDATE_TIME >=:lastUpdateTime
            ]]></sql>
        </sql-increment-checker>
    </cache-update-checkers>
</sagacity>
```

缓存翻译的完整用法见[缓存翻译使用](../quickstart/translates.md)。

## 四、Java 调用

通过 `lightDao.mongo()` 链式调用（`sql` 传 mql 的 id）：

```java
// 通过对象传参查询
PospTransDetailVO queryVO = new PospTransDetailVO();
queryVO.setTransType("N");
queryVO.setTransAmt(0d);
List<PospTransDetailVO> result = (List<PospTransDetailVO>) lightDao.mongo()
        .sql("sqltoy_mongo_find")
        .resultType(PospTransDetailVO.class)
        .entity(queryVO)
        .find();

// 通过 names/values 传参 + 分页
Page page = lightDao.mongo()
        .sql("sqltoy_mongo_find")
        .resultType(PospTransDetailVO.class)
        .names("transType", "transAmt", "flag").values("N", 13800, 2)
        .findPage(new Page<>());

// 聚合查询
List aggResult = lightDao.mongo()
        .sql("sqltoy_mongo_agg")
        .names("transType", "transAmt").values(null, null)
        .find();
```

`mongo()` 链式可设置：`sql`、`names`、`values`、`entity`、`resultType`、`humpMapLabel`；终止方法：`find()`、`getOne()`、`findTop(Float)`、`findPage(Page)`。

## 五、注意事项

- sqltoy 对 mongo **只做查询**，增删改请用 `MongoTemplate`（对象注解 `@Document`/`@Id`/`@Field`）。
- 缓存翻译配合 `fields` 别名 + `original-columns`，可在不写关联查询的情况下完成码值翻译。
- 聚合结果通过 `fields` 的 `_id.xxx:别名` 提取嵌套字段后再翻译/处理。
