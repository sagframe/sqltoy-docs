# 从 MyBatis / MyBatis-Plus 迁移到 sqltoy

sqltoy 与 MyBatis 的**动态 SQL 心智完全一致**（SQL 写在 xml、条件按需拼），差别在于"条件怎么表达"和"对象操作有多强"。迁移通常是**渐进式**的：先让新写的查询走 sqltoy，再逐步改造旧 Mapper。

## 一、概念对照

| MyBatis / MyBatis-Plus | sqltoy 对应 | 说明 |
| --- | --- | --- |
| Mapper XML 的 `<select id="findXxx">` | `*.sql.xml` 的 `<sql id="findXxx">` | 文件按模块放，支持 debug 热加载 |
| `<if test="x!=null"> and t.a=#{x}</if>` | `#[and t.a=:x]` | 参数为 null 自动剔除，**SQL 能直接粘到客户端执行** |
| `<where>` / `<trim prefixOverrides>` | `where 1=1` + `#[]` | 不需要 `<where>` 标签兜底 |
| `#{}` | `:name` 命名参数 | 最终都转成 `?` 走 `PreparedStatement` |
| `${}`（字符串拼接） | `@value(:name)` / `@joinFields(:cols,default)` | 标识符场景有白名单校验，见[标签与表达式](../appendix/tags.md) |
| `<foreach collection="ids">` | `t.id in (:ids)` | 数组/集合自动展开，超 1000 自动切分 |
| ResultMap + `<result column="A" property="a">` | 结果类型（VO/POJO）+ 列别名 `AS a` | 列名与属性名不一致用 `@SqlToyFieldAlias` |
| `<collection>` 嵌套映射 | 层次封装（hiberarchy）或按 VO 平铺 | 一条 join SQL 封装父子对象，见[常规查询 API](../query/sqltoy_query.md) |
| 分页插件（PageHelper 等） | `findPage` | 自动 count 优化 + `@fast` + 并行分页 |
| `@Select` 注解 | `@Sql` 注解 / 代码内 SQL | 复杂 SQL 仍建议放 xml |
| MP `QueryWrapper` / `LambdaQueryWrapper` | `EntityQuery` / `LambdaQuery` | 前者字符串条件，后者属性引用 |
| MP `BaseMapper` / `IService` | `LightDao` / `SqlToyCRUDService` | `LightDao` 约 110 个方法，见 [API 速查](../appendix/api.md) |
| MP `@TableLogic` 逻辑删除 | 统一 SQL 片段 / 拦截器 | sqltoy 不内置逻辑删除，用 `<sql>` 公共片段或 `SqlInterceptor` 统一加条件 |
| MP `@Version` 乐观锁 | `@DataVersion` | 见[数据版本控制](../enterprise/data_version.md) |
| MP `@TableField(fill=...)` | `unifyFieldsHandler` | 统一补漏赋值，见[增加公共字段处理](../quickstart/helloworld_improve.md) |

## 二、落地顺序（建议按此推进）

1. **依赖与配置**：引入 `sagacity-sqltoy-spring-starter`，配 `sqlResourcesDir` + `debug=true`，见[开发环境与依赖](../prepare/environment.md)；
2. **建 SQL 目录**：按模块建 `*.sql.xml`（如 `com/acme/crm/modules/staff.sql.xml`），先把**新需求**写成 sqltoy 形式，不动旧 Mapper；
3. **生成 POJO**：用 [quickvo](../prepare/quickvo.md) 按现有表生成实体（注解齐全，别手写）；
4. **改造查询**（收益最大、风险最低）：从"条件最多、最难维护"的查询开始，按第三节对照改写；
5. **改造写入**：把"先 load 再改再 update"换成弹性更新；高并发台账类改为 `updateSaveFetch`（查增改一体）；
6. **灰度与校验**：新旧实现并行跑一段时间，对比结果集（sqltoy 的 `redoDataSources` 可帮你在另一套库上重放验证，见[多库适配验证](../dialect/multi_db_verify.md)）。

## 三、典型改写

### 3.1 多条件动态查询

```xml
<!-- MyBatis -->
<select id="findOrder">
    select * from sqltoy_order_info t
    <where>
        <if test="beginDate!=null"> and t.trans_date &gt;= #{beginDate} </if>
        <if test="endDate!=null"> and t.trans_date &lt;= #{endDate} </if>
        <if test="status!=null and status!=''"> and t.status=#{status} </if>
        <if test="orderId!=null and orderId!=''"> and t.order_id=#{orderId} </if>
    </where>
</select>
```

```xml
<!-- sqltoy：条件与 SQL 不割裂，可直接粘到客户端跑 -->
<sql id="findOrder">
    <value><![CDATA[
        select * from sqltoy_order_info t
        where 1=1
        #[and t.trans_date>=:beginDate]
        #[and t.trans_date<=:endDate]
        #[and t.status=:status]
        #[and t.order_id=:orderId]
    ]]></value>
</sql>
```

`status!=''` 这类"空串也当没传"的诉求用 filter 统一处理，不必在每处判断：

```xml
<filters>
    <!-- 空白串转 null，从而剔除对应的 #[] 片段 -->
    <blank params="status,orderId" />
</filters>
```

### 3.2 like 查询

```xml
<!-- MyBatis: concat('%',#{name},'%') -->
<!-- sqltoy: 通配符由框架补 -->
#[and t.staff_name like :staffName]
<filters>
    <r-like params="staffName" />   <!-- 值后补 %：以 name 开头 -->
</filters>
```

### 3.3 集合 in 与空集合

```xml
#[and t.organ_id in (:organIds)]
```

- 传 `List`/数组即自动展开成多个 `?`；
- **空集合自动跳过该条件**（不会生成 `in ()` 语法错误）；
- 超过 1000 个值自动切分（Oracle 限制）。

### 3.4 分页

```java
// MyBatis-Plus
Page<OrderInfo> page = orderMapper.selectPage(new Page<>(pageNo, pageSize), wrapper);
```

```java
// sqltoy
Page<OrderInfoVO> page = lightDao.findPage(new Page(pageSize, pageNo),
        "crm_order_findlist", paramsMap, OrderInfoVO.class);
```

分页 SQL 里的 count 由框架改写（剔除 order by、裁剪 select 列）；大表 join 分页用 `@fast()`，见[分页优化](../query/pagination.md)。

### 3.5 单表条件更新

```java
// MyBatis-Plus
new LambdaUpdateWrapper<StaffInfo>()
        .set(StaffInfo::getStatus, 2)
        .eq(StaffInfo::getStaffId, id)
```

```java
// sqltoy：单表用 lambda（复用实体链路，分片/翻译/租户都生效）
lightDao.lambdaUpdate(StaffInfo.class)
        .set(StaffInfo::getStatus, 2)
        .eq(StaffInfo::getStaffId, id)
        .update();

// 或字符串条件
lightDao.updateByQuery(StaffInfo.class,
        EntityUpdate.create().set("status", 2).where("staff_id=?").values(id));
```

### 3.6 先查后改 → 弹性更新 / 查增改一体（updateSaveFetch）

```java
// MyBatis 常见写法：load → 判断 → update（两次交互，且可能覆盖并发修改）
OrderInfo o = mapper.selectById(id);
o.setStatus(2);
mapper.updateById(o);
```

```java
// sqltoy 弹性更新：update 本身就是弹性的——一次交互，null 字段不参与
// （不会误清空别人改过的字段，也不用手拼 update set 片段）
OrderInfo orderInfo = new OrderInfo();
orderInfo.setOrderId(id);
orderInfo.setStatus(2);
lightDao.update(orderInfo);

// 高并发"查、增、改"：一次交互完成 锁查询 → 存在则修改、不存在则插入 → 返回结果
// uniqueProps 指定业务唯一键属性（不传则按主键检索）；回调中 entity 为代理对象，
// get 读数据库当前值、set 写回当前行，抛异常则整体回滚
OrderInfo entity = new OrderInfo();
entity.setOrderId(id);
entity.setStatus(2);
OrderInfo order = lightDao.updateSaveFetch(
        entity,
        (loaded, rowIndex) -> {
            if (!"1".equals(loaded.getStatus())) {
                throw new IllegalStateException("状态已变更，请刷新后重试");
            }
            loaded.setStatus(2);
        },
        "orderId");
```

> 若记录**必然存在**、且需自由编写查询条件与锁策略，则用 `updateFetch`（sql + `UpdateRowHandler`，见[对象化 CRUD 第 10 节](../crud/sqltoy_crud.md)）；台账类"存在则改、不存在则插"优先 `updateSaveFetch`。

### 3.7 批量插入

```java
// MyBatis: foreach 拼 values（SQL 长度随数据量爆炸）
// sqltoy: 批量接口，自动分批（batchSize 默认 200）
lightDao.saveAll(list);
lightDao.saveAllIgnoreExist(list);   // 已存在则跳过
```

## 四、常见坑

| 现象 | 原因与处理 |
| --- | --- |
| SQL 里参数没生效 | sqltoy 命名参数**大小写敏感**，且 `#[]` 内的参数名必须与传入 Map 的 key 完全一致 |
| 结果属性全为 null | 列名与属性名不一致：加 `AS` 别名，或配置 `humpMapResultTypeLabel` / 用 `@SqlToyFieldAlias` |
| `in` 报语法错 | 用了字符串拼接而不是 `:ids`；空集合交给框架跳过即可 |
| 分页总数比数据少 | 用了 `@fast` + 外层 join 过滤，count 走内层 SQL；用 `<count-sql>` 显式指定，见 [FAQ 十](../faq/faq.md) |
| 动态 SQL 想拼标识符 | 不要用 `@value` 直拼用户输入；用 `@joinFields`（白名单）或 `<valid-sqlInjection>` |
| 逻辑删除条件到处写 | sqltoy 无内置逻辑删除，用公共 `<sql>` 片段 `@include` 或 `SqlInterceptor` 统一注入 |
| 事务行为不一样 | 对象操作沿用 Spring `@Transactional`；跨库/多数据源见[多数据源与事务](../config/dynamic_datasource.md) |

## 五、迁移后能拿到什么

- **查询**：SQL 保持原生形态（可粘客户端调试）、智能 count、`@fast`、并行分页、缓存翻译免 join；
- **写入**：弹性更新 / `updateFetch` / `updateSaveFetch` 把"多次交互 + 手工加锁"变成一个方法调用；
- **跨库**：25 种方言 + 函数自动替换，同一份 SQL 跑多个库；
- **数据分析**：pivot/unpivot、同比环比、树形汇总在内存完成，不必为每个数据库写不同 SQL。

> 相关：[必杀集锦](../best/best_practices.md)（sqltoy 与 MyBatis 写法对比）、[功能清单](feature.md)、[API 速查](../appendix/api.md)
