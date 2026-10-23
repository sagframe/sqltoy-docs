# 数据权限传参和越权校验

企业系统里"当前用户能看哪些机构/账套/租户/业务线"这类信息，通常是**每次查询都要带、但业务代码不该操心**的。sqltoy 把它拆成两层能力：

| 能力 | 解决的痛点 | 实现位置 |
| --- | --- | --- |
| **统一传参 + 越权校验** | 前端没传 → 自动填充授权值；前端传了 → 校验是否越权，越权直接抛异常 | `IUnifyFieldsHandler.dataAuthFilters()` |
| **按维度自动过滤** | 连参数都不想让前端传：直接往 SQL 里注入 `tenant_id='x'` 之类的过滤条件 | `SqlInterceptor`（内置 `TenantFilterInterceptor`） |

## 一、统一传参 + 越权校验（dataAuthFilters）

### 1.1 机制

`IUnifyFieldsHandler` 的 `dataAuthFilters()` 返回一张 **"SQL 参数名 → 授权配置"** 的表。框架在每次查询/执行前，对 SQL 里的**同名参数**做判断：

```java
public default IgnoreKeyCaseMap<String, DataAuthFilterConfig> dataAuthFilters() {
    return null;   // 默认不启用
}
```

处理逻辑（每个命名参数独立判断）：

| 前端传值情况 | 框架行为 |
| --- | --- |
| 参数为空（null/空白），或等于 `choiceAllValue`（"全选"标记） | **自动把授权范围 `values` 填进该参数**（统一传参，业务代码不用管） |
| 参数有值且 `isForcelimit=true` | 把传入的每个值与授权集合比对，**任一值越界即抛 `DataAccessException`** |
| 参数有值但 `isForcelimit=false` | 不做越权校验，以前端传值为准 |

越权异常形如：

```text
param [organId] value [S004] is beyond the authorized scope
(see the implementation configured by spring.sqltoy.unifyFieldsHandler), please check!
```

### 1.2 DataAuthFilterConfig 属性

| 属性 | 说明 |
| --- | --- |
| `values` | **授权值**：数组、集合或单值，来自当前登录用户的授权范围（机构 id、账套 id、租户 id…） |
| `choiceAllValue` | "全选"标记值（如页面下拉的"全部"传 `-1`）；传入该值时视为未指定，改用 `values` |
| `isForcelimit` | 是否强制约束（默认 `true`）；`false` 时不做越权校验 |
| `ignoreType` | 越权比对时是否忽略类型（如前端传 `String`、授权值是 `BigInteger`） |

### 1.3 实现示例

```java
@Component("unifyFieldsHandler")
public class SqlToyUnifyFieldsHandler implements IUnifyFieldsHandler {

    /** 当前登录用户上下文（由过滤器/拦截器写入 ThreadLocal） */
    @Override
    public IgnoreKeyCaseMap<String, DataAuthFilterConfig> dataAuthFilters() {
        IgnoreKeyCaseMap<String, DataAuthFilterConfig> map = new IgnoreKeyCaseMap<>();
        // ① 机构维度：SQL 里的 :organId 参数
        map.put("organId", new DataAuthFilterConfig()
                .setValues(getAuthOrganIds())      // String[]: 授权机构
                .setChoiceAllValue("-1")           // 前端"全部"传 -1 时，改用授权范围
                .setForcelimit(true));             // 越权即抛异常
        // ② 账套维度：授权值是数字类型，前端传字符串
        map.put("accountSetId", new DataAuthFilterConfig()
                .setValues(getAuthAccountSetIds())
                .setIgnoreType(true));
        return map;
    }
}
```

配置（`unifyFieldsHandler` 同时承担公共字段赋值，本机制复用同一个实现）：

```properties
spring.sqltoy.unifyFieldsHandler=com.yourproject.SqlToyUnifyFieldsHandler
```

### 1.4 SQL 侧怎么写

参数名与 `dataAuthFilters()` 的 key **一一对应**即可，无需任何额外标签：

```xml
<sql id="staff_findlist">
    <value><![CDATA[
        select * from sqltoy_staff_info t
        where t.status=1
        #[and t.organ_id in (:organId)]
        #[and t.tenant_id=:tenantId]
    ]]></value>
</sql>
```

- 前端不传 `organId`（或传 `-1`）→ 框架自动填入授权机构；
- 前端传 `organId=S004` 而授权只有 A/B/C → 抛越权异常；
- 传多个值（数组/逗号串经 `<split>` 过滤器）时逐个比对。

### 1.5 注意事项

- **参数名必须对齐**：这是最容易踩的坑——SQL 里改名了但 `dataAuthFilters()` 没改，机制会静默失效（参数为空 → 只填授权值反而"看起来正常"，越权校验却不生效）；
- **授权值来源必须可信**：`values` 应由服务端从登录态推导，不能来自前端；
- **只对"有该命名参数"的 SQL 生效**：SQL 里没写这个参数，机制不会凭空注入条件（需要"无条件也过滤"请用第二节的拦截器）；
- **分页 count 缓存**：`values` 是分页 count 缓存 key 的组成部分之一，授权范围变化会自然换 key，不会串数；
- 单表实体链路（`findEntity`/`updateByQuery`/`deleteByQuery`）与非实体查询一致生效。

## 二、按维度自动过滤（TenantFilterInterceptor）

当过滤条件是"所有查询都要带、且前端根本不用传"时，用 SQL 拦截器更彻底：它在最终 SQL 上注入条件，业务 SQL 与参数都不用出现该字段。

### 2.1 配置

```properties
# 内置租户/机构过滤拦截器
spring.sqltoy.sqlInterceptors[0]=org.sagacity.sqltoy.plugins.interceptors.TenantFilterInterceptor
# 拦截器依赖统一字段处理器提供授权值
spring.sqltoy.unifyFieldsHandler=com.yourproject.SqlToyUnifyFieldsHandler
```

### 2.2 授权值从哪来

拦截器向 `IUnifyFieldsHandler` 取两个值：

```java
/** 当前用户授权的租户/机构 id 数组；operType 可区分查询/分页/top/random/count 等场景 */
public default String[] authTenants(Class entityClass, OperateType operType) { ... }

/** 单租户简化形态：只返回当前用户的租户 id */
public default String getUserTenantId() { ... }
```

`authTenants` 优先，返回空时回退 `getUserTenantId`；两者都为空则**不做过滤**（fail-open，注意这是"没配就不拦"的设计，不是"拦住所有"）。

> 分页场景建议实现 `authTenants`：分页 count 缓存需要该值参与 key 组成，否则不同租户会命中同一份 count。

### 2.3 注入规则

- 租户字段来源：实体上的 `@Tenant(field="...")`，或按约定列名（如 `tenantId`）；
- 仅对**有实体类型**的操作生效（对象 CRUD、`findEntity`、`findPageEntity`、`updateByQuery`、`deleteByQuery` 等）；**纯 sqlId 查询没有实体，不会注入**；
- SQL 里已有该租户条件（`where` 段已出现 `tenant_id=` / `tenant_id in`）时**不重复注入**；
- 没有 `where` 的 SQL 会把条件追加到 `group by`/`order by` 之前；
- `saveOrUpdate`（merge）场景注入到 `on` 子句；
- 授权值以**字面量**拼入（框架对单引号做了转义），值必须来自可信来源。

### 2.4 与多租户的关系

本节的机制同时是多租户隔离的实现方式之一：`@Tenant` + `TenantFilterInterceptor` 统一过滤与赋值。多租户的完整用法（含写入时自动补租户字段）见[多租户支持](enterprise/sqltoy_multitenant.md)。

## 三、两种方式怎么选

| 场景 | 选择 |
| --- | --- |
| 页面上有"机构/账套"筛选条件，用户可能选可能不选 | `dataAuthFilters()`（统一传参 + 越权校验） |
| 数据隔离必须无条件生效（SaaS 租户、数据权限强隔离） | `TenantFilterInterceptor`（自动注入） |
| 既要隔离、又要在前端越权时**报错提示** | `dataAuthFilters()` + `isForcelimit=true` |
| 过滤维度不是实体字段（跨表、复杂表达式） | 自定义 `SqlInterceptor`，见 [SQL 拦截加工](enterprise/sql_interceptor.md) |

> 两者可同时使用：拦截器负责"兜底隔离"，`dataAuthFilters` 负责"前端可见条件的填充与越权提示"。

## 四、相关

- 多租户完整用法：[多租户支持](enterprise/sqltoy_multitenant.md)
- 自定义 SQL 加工：[SQL 拦截加工](enterprise/sql_interceptor.md)
- 统一字段处理器接口（含 `createUnifyFields`/`updateUnifyFields`）：[增加公共字段处理](quickstart/helloworld_improve.md)
- 配置项总览：[sqltoy 配置参数](config/sqltoy_config.md)
