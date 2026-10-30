# TDengine 时序数据库支持

**说明**：TDengine 是面向 IoT 的**时序数据库**（append-only 追加写模型），sqltoy 对其支持定位为 **「查询 + 对象插入」**，与关系型数据库的全功能 CRUD 不同。出发点是：在多数据源场景下（如 MySQL 管业务、TDengine 管设备遥测），用统一的 sqltoy API 完成时序数据的查询与写入，并复用 sqltoy 的动态条件、缓存翻译、结果集算法等能力。

> 本文支持边界基于 **TDengine 3.3.6.x + taos-jdbcdriver 3.3.0** 实测验证（REST 连接模式）。
>
> 时序库为追加写模型：**没有 `UPDATE ... SET` 语句、没有行级锁、没有存储过程、没有自增/序列**，这些是引擎语义所限，并非框架缺陷。下文「四、不支持的操作」给出每项的替代方案。

## 一、连接配置

TDengine 提供两种 JDBC 连接方式，按需选用：

| 方式 | URL 形态 | 驱动类 | 说明 |
| --- | --- | --- | --- |
| REST（推荐） | `jdbc:TAOS-RS://host:6041/db` | `com.taosdata.jdbc.rs.RestfulDriver` | 纯 Java，经 taosAdapter 的 HTTP 接口，无需本地客户端库 |
| 原生 | `jdbc:TAOS://host:6030/db` | `com.taosdata.jdbc.TSDBDriver` | 需在应用服务器安装 taos 客户端库，性能更高 |

Maven 依赖：

```xml
<dependency>
    <groupId>com.taosdata.jdbc</groupId>
    <artifactId>taos-jdbcdriver</artifactId>
    <version>3.3.0</version>
</dependency>
```

数据源配置（以 REST 为例）：

```yaml
spring:
  datasource:
    url: jdbc:TAOS-RS://192.168.56.101:6041/testdb
    username: root
    password: taosdata
    driver-class-name: com.taosdata.jdbc.rs.RestfulDriver
```

**方言识别**：TDengine 驱动上报的产品名为 `TDengine`，sqltoy 会**自动识别**为 `tdengine` 方言（`DBType=150`），无需手动指定；如需强制，也可显式配置 `spring.sqltoy.dialect=tdengine`。

## 二、支持的操作

### 2.1 查询（完整支持）

`findBySql` / `findPageBySql` / `findTopBySql` / `getRandomResult` / `getCountBySql` / `load` / `loadAll` 均走通用路径，实测可用：

- 分页 `limit ? offset ?`、`count(1)` / `count(*)`、随机查询 `order by rand()` TDengine 3.x 均原生支持；
- 时间戳列与字符串可直接比较（隐式转换），日期条件参数绑定无忧；
- 查询超级表时，**标签（tags）会作为普通列出现在结果集中**，可直接映射到 VO 字段。

```xml
<sql id="meter_query">
    select ts, current, voltage, location, groupId
    from meters
    <where>
        <isNotEmpty property="location">and location = :location</isNotEmpty>
        <isNotEmpty property="beginTime">and ts &gt;= :beginTime</isNotEmpty>
    </where>
    order by ts desc
</sql>
```

```java
// 分页查询（框架自动拼 limit ? offset ? 与 count）
QueryResult<MeterVO> page = dao.findPageBySql(
    new QueryExecutor("meter_query")
        .setParam("location", "California")
        .setParam("beginTime", beginTime)
        .setResultType(MeterVO.class),
    pageNo, pageSize);
```

### 2.2 对象插入

时序库的写入有两种模式，按场景选用：

**模式 A：`save` / `saveAll` 写已存在的子表/普通表**

框架生成标准单表列清单 insert（`insert into 子表 (ts,current,...) values(?,?)`），适用于子表已建好的场景。注意：

- 实体主键必须是**时间戳列**且用 **ASSIGN** 策略（见「三、使用约束」）；
- 实体只应包含**普通列**（ts、current、voltage…），**不要包含标签列**——标签是子表级元数据，写入子表时不作为行字段，否则 insert 列清单会带上标签列导致报错；
- 一设备一子表时，可结合[分库分表](enterprise/sqltoy_sharding.md)的分表策略按设备路由到各自子表（框架按表名分组批量写入）。

**模式 B（时序典型）：sql xml 命名参数做「自动建子表 + 标签」写入**

TDengine 最地道的写入是 `insert into 子表 using 超级表 tags(...) values(...)`，子表不存在时自动创建。sqltoy 用 sql xml 命名参数即可表达，**无需任何额外开发**：

```xml
<sql id="device_insert">
    insert into :tb using meters tags(:location, :groupId)
    values(:ts, :current, :voltage, :phase)
</sql>
```

```java
// 单条：executeSql
dao.executeSql("device_insert",
    MapKit.keys("tb", "location", "groupId", "ts", "current", "voltage", "phase")
          .values("d1001", "California", 1, ts, 10.2f, 219, 0.31f));

// 批量：batchUpdate，每行可传不同的 :tb，一条 PreparedStatement 跨多张子表自动建表
List<Map<String, Object>> rows = ...; // 每个 Map 含 tb/location/groupId/ts/current/...
dao.batchUpdate("device_insert", rows);
```

**原理（实测验证）**：`:tb` 经 sqltoy 命名参数处理转为 `?` 占位符，最终 SQL 为 `insert into ? using meters tags(?,?) values(?,?,?,?)`；TDengine JDBC 驱动在客户端把表名位置的 `?` 正确绑定为标识符（而非加引号的字符串），TAGS 与 VALUES 的 `?` 正常绑定。`addBatch` 时每行可设置不同子表名，**一条语句即可批量写入并自动创建多张子表**。

## 三、使用约束

1. **时间戳主键由应用赋值（ASSIGN 策略）**：TDengine 官方 INSERT 文档明确——「每条插入行**必须包含时间戳，且时间戳不能为 `NULL`**」「时间戳主键**必须出现，不能省略**」。TDengine 无自增列、无序列，`getGeneratedKeys` 不支持（实测报 `this operation is NOT supported`），故主键须用 **ASSIGN** 策略由应用赋值，切勿配置 `identity` / `sequence`。
   - **关于 `NOW`**：官方明确「`NOW` 解析为**客户端时间**（client time），而非服务端时间」。因此应用侧 `new Timestamp(System.currentTimeMillis())` 与在 SQL 里写 `NOW` **本质等价**（都取客户端时钟），并不存在“服务端自动生成时间戳”这回事（TDengine 连 `current_timestamp` 都不支持）。但应用赋值**更优**：应用知道所赋的值，`save()` 能正常返回主键；而 `NOW` 生成的时间戳**不回传**，实体拿不到自己的主键。
   - **语义建议**：IoT 场景时间戳应取**事件时间**（采样那一刻），由设备/应用掌握；`NOW` 只是“写语句的客户端时刻”，在设备时钟漂移或补传历史数据时会失真。
2. **子表名防注入**：模式 B 的 `:tb` 由驱动内联进 SQL 文本，**务必在 service 层对子表名做白名单/合法性校验**，避免 SQL 注入。
3. **不要直接映射超级表写入**：`insert into 超级表 ... values(...)` 会被引擎拒绝（`tbname column should not be null`），写入必须落到子表（模式 B 的 `using ... tags` 会自动建子表）。
4. **批量写入用模式 B**：`saveAll` 仅写单一已存在子表；跨多设备的批量摄入用模式 B 的 `batchUpdate`（每行不同 `:tb`），或分表策略路由。
5. **「更新」= 相同时间戳重新 INSERT**：TDengine 无 `UPDATE` 语句。官方规则——「一个主键只保留一行，时间戳单独标识该行」「相同时间戳的行会互相覆盖」。因此修改一条记录的唯一方式是**用相同时间戳重新插入**；3.x 为**列级合并**（只覆盖本次 INSERT 出现的列，未出现的列保留原值，实测验证）。这也意味着 `update` / `saveOrUpdate` 等 ORM 写操作在 TDengine 上不适用（见下节），需要“改值”时按此机制重插即可。

## 四、不支持的操作及替代方案

以下操作受 TDengine 引擎语义所限而不可用（框架抛 `UnsupportedOperationException`）。原因与替代方案如下：

| 操作 | 引擎原因 | 替代方案 |
| --- | --- | --- |
| `update` / `updateAll` | 无 `UPDATE ... SET` 语句（追加写模型） | 用**相同时间戳重新 INSERT** 覆盖；3.x 为列级合并（只覆盖 INSERT 中出现的列，其余保留原值） |
| `saveOrUpdate` / `saveOrUpdateAll` | 无 UPSERT 语义 | 同上，相同时间戳重插即覆盖 |
| `saveAllIgnoreExist` | 无 `INSERT IGNORE` / `ON CONFLICT` | 重复时间戳本身即覆盖写，无需 ignore |
| 行级锁（`LockMode` / `for update`） | 无行级锁（`SELECT ... FOR UPDATE` 报语法错误） | 查询时**请勿传 `LockMode`**（6.0.9 会拼出 `for update` 导致语法错误）；时序读取本就无需加锁 |
| `updateFetch` | 无 UPDATE 且无行锁 | 不适用 |
| `executeStore`（存储过程） | 无存储过程 | 用 TDengine 流计算或应用层逻辑 |
| `delete` / `deleteAll`（ORM 按主键） | ORM 按主键删除未启用 | 数据过期用**库级 `KEEP` 策略**自动清理；或经 sql xml 手写 `DELETE`（主要按时间范围） |
| `isUnique` | 无关系库唯一约束校验语义 | 时间戳主键天然唯一，重复时间戳为覆盖写 |

## 五、函数与方言注意

- TDengine **没有** `coalesce` / `nvl` / `ifnull` / `date_format` 等函数（实测 `Func not exists`），跨库函数自动替换（`functionConverts=default`）对这些函数**无对应目标**，会原样保留，编写跨库 SQL 时需注意；
- 日期格式化用 TDengine 的 `to_char(ts, 'YYYY-MM-DD HH24:MI:SS')`（**Oracle 风格格式符**，3.2.1.0+ 支持），字符串转时间戳用 `to_timestamp`；
- 保留字标识符用反引号（与 MySQL 系一致），框架已自动处理；
- 如需为 TDengine 提供专属 SQL，可用 `sqlId_tdengine` 方言变体（见[方言自适配与函数扩展](dialect/sqltoy_function.md)）。

## 六、相关

- 支持的数据库总览：[支持的数据库](introduction/db_list.md)
- 跨库适配与多库验证：[多种数据库适配验证](dialect/multi_db_verify.md)
- 分表策略（一设备一子表路由）：[分库分表](enterprise/sqltoy_sharding.md)
