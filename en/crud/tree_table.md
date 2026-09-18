# Tree-Table Route Builder

For **tree tables** such as organization structures, administrative divisions and product categories, a node route field (e.g. `node_route`) is usually kept redundantly so that an entire subtree can be fetched **non-recursively** with `like 'route%'`, avoiding the database pressure caused by layer-by-layer recursive queries. `wrapTreeTableRoute` builds and maintains these redundant fields: **node route (nodeRoute), hierarchy level (nodeLevel), leaf flag (leaf)**.

## 1. API

```java
/**
 * Builds the required information of a tree table, such as the node route, hierarchy level and leaf flag
 * @param treeTableModel tree table model object, providing the hierarchical structure configuration such as the id field and the pid parent field
 * @return returns true on success, false on failure
 */
public boolean wrapTreeTableRoute(final TreeTableModel treeTableModel);
```

Equivalent chainable form: `lightDao.treeTable().treeModel(treeTableModel).submit()`

## 2. TreeTableModel Configuration

Two construction modes: **entity-based** (the table name is taken from the `@Entity` annotation) or **table-name-based** full-argument construction `(tableName, pidValue, idField, pidField, nodeRouteField, nodeLevelField, leafField, isChar, idLength)`.

| Configuration | Description |
| --- | --- |
| `idField` / `pidField` | primary key field / parent field |
| `rootId` (`pidValue`) | parent value of the root node (e.g. `0`) |
| `nodeRouteField` | node route field, in the form `,100008,100009,` |
| `nodeLevelField` | hierarchy level field |
| `isLeafField` (`leafField`) | leaf flag field |
| `idLength` / `idTypeIsChar` | id length / whether character type (for fixed-length hierarchical concatenation) |
| `setConditions` | additional filter conditions |
| `appendZero` | whether to pad with zeros |
| `splitSign` | route separator |

## 3. Usage Example

```java
// Mode 1: entity object based (the table name is taken from the @Entity annotation)
lightDao.wrapTreeTableRoute(new TreeTableModel(organInfo)
        .idField("organCode").pidField("organPid")
        .nodeRouteField("nodeRoute").nodeLevelField("nodeLevel")
        .isLeafField("leafField"));

// Mode 2: table-name-based full-argument construction
// (tableName, root parent value pidValue, idField, pidField, nodeRouteField, nodeLevelField, leafField, isChar, idLength)
lightDao.wrapTreeTableRoute(new TreeTableModel("sqltoy_organ_info", "0",
        "organ_id", "organ_pid", "node_route", "node_level", "leaf_field", true, 4));
```

Once built, the route field can be used to efficiently query an entire subtree:

```xml
<sql id="sqltoy_treeTable_search">
    <value><![CDATA[
        select * from sqltoy_organ_info t
        where t.node_route like :nodeRoute
    ]]></value>
</sql>
```

```java
// query all children under a node (nodeRoute in the form ",100008,")
List<OrganInfoVO> subOrgans = lightDao.find("sqltoy_treeTable_search",
        MapKit.map("nodeRoute", ",100008,"), OrganInfoVO.class);
```

## 4. Notes

- When a unified field handler (`unifyFieldsHandler`) is configured, the route cascade and leaf-flag update statements **automatically append** the common update fields from `updateUnifyFields()` (e.g. last modified by, last modified time); columns are matched by entity property names, and fields not present in the entity are ignored automatically.
- For the **query-side sorting and layer-by-layer summary** of tree tables (the `<tree-sort>` tag), see [Complex Query & Analytics](../query/sqltoy_complex_query.md); combining the two yields a complete tree solution of "route building + sorting and summary".
- For declaring object cascade relationships (`@OneToMany`/`@OneToOne`), see [Object CRUD](sqltoy_crud.md).
