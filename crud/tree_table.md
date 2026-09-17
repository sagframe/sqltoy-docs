# 树形表节点路径构造（wrapTreeTableRoute）

组织机构、行政区划、商品分类等**树形表**，通常冗余一个节点路径字段（如 `node_route`），用 `like '路径%'` 即可**非递归**查出整棵子树，避免逐层递归查询带来的数据库压力。`wrapTreeTableRoute` 用于构造与维护这些冗余字段：**节点路径（nodeRoute）、层次等级（nodeLevel）、是否叶子节点（leaf）**。

## 一、API

```java
/**
 * 构造树形表的节点路径、层次等级、是否叶子节点等必要信息
 * @param treeTableModel 树形表模型对象，提供id字段、pid父级字段等层级结构配置
 * @return 包装处理成功返回true，失败返回false
 */
public boolean wrapTreeTableRoute(final TreeTableModel treeTableModel);
```

等价链式写法：`lightDao.treeTable().treeModel(treeTableModel).submit()`

## 二、TreeTableModel 配置

两种构造模式：**基于实体**（表名取自 `@Entity` 注解）或**基于表名**全参构造 `(tableName, pidValue, idField, pidField, nodeRouteField, nodeLevelField, leafField, isChar, idLength)`。

| 配置 | 说明 |
| --- | --- |
| `idField` / `pidField` | 主键字段 / 父级字段 |
| `rootId`（`pidValue`） | 根节点的父级值（如 `0`） |
| `nodeRouteField` | 节点路径字段，形如 `,100008,100009,` |
| `nodeLevelField` | 层次等级字段 |
| `isLeafField`（`leafField`） | 是否叶子节点字段 |
| `idLength` / `idTypeIsChar` | id 长度 / 是否字符型（层级定长拼接场景） |
| `setConditions` | 附加过滤条件 |
| `appendZero` | 是否补零 |
| `splitSign` | 路径分隔符 |

## 三、使用范例

```java
// 方式一：基于实体对象（表名取自 @Entity 注解）
lightDao.wrapTreeTableRoute(new TreeTableModel(organInfo)
        .idField("organCode").pidField("organPid")
        .nodeRouteField("nodeRoute").nodeLevelField("nodeLevel")
        .isLeafField("leafField"));

// 方式二：基于表名全参构造
// (tableName, 根父级值pidValue, idField, pidField, nodeRouteField, nodeLevelField, leafField, isChar, idLength)
lightDao.wrapTreeTableRoute(new TreeTableModel("sqltoy_organ_info", "0",
        "organ_id", "organ_pid", "node_route", "node_level", "leaf_field", true, 4));
```

构造完成后，即可用路径字段高效查询整棵子树：

```xml
<sql id="sqltoy_treeTable_search">
    <value><![CDATA[
        select * from sqltoy_organ_info t
        where t.node_route like :nodeRoute
    ]]></value>
</sql>
```

```java
// 查询某节点下全部子级（nodeRoute 形如 ",100008,"）
List<OrganInfoVO> subOrgans = lightDao.find("sqltoy_treeTable_search",
        MapKit.map("nodeRoute", ",100008,"), OrganInfoVO.class);
```

## 四、说明

- 配置了统一字段处理器（`unifyFieldsHandler`）时，路由级联与叶子标记更新的语句会**自动附加** `updateUnifyFields()` 中的公共更新字段（如最后修改人、最后修改时间），按实体属性名匹配列名，实体中不存在的字段自动忽略。
- 树形表的**查询侧排序与逐层汇总**（`<tree-sort>` 标签）见[复杂查询与数据分析](../query/sqltoy_complex_query.md)；二者配合可实现"构造路径 + 排序汇总"的完整树形方案。
- 对象的级联关系声明（`@OneToMany`/`@OneToOne`）见[对象化 CRUD](sqltoy_crud.md)。
