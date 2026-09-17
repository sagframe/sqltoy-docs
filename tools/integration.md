# 扩展集成（报表 / 低代码平台）

sqltoy 打造的并不仅仅面向常规应用开发（管理系统后台、微服务接口实现等），还面向**报表平台**以及目前流行的**低代码平台**（基于页面配置化完成传统功能页面、接口服务开发部署的新开发业态）。

例如基于 sqltoy 开发的：

- **sagacity-rainbow**：快速接口开发框架；
- **sagacity-nebula**：报表框架。

## 一、集成方式

核心是把 SQL 的 xml 片段交由 `SqlToyContext` 托管。报表/低代码平台在运行时动态产生或加载 SQL 配置，由 sqltoy 负责解析、参数绑定、方言适配与执行。

## 二、参数绑定：getFullParamNames

集成时常见的疑问是：**怎么把（报表/页面的）条件参数跟 SQL 里的条件参数绑定？**

如果是报表，通常会把条件参数以 Map 形式组织起来。`SqlToyConfig` 提供了 `getFullParamNames` 方法，让你获取一条 SQL 中的**全部参数名称**，从而把外部条件 Map 与 SQL 参数对齐：

```java
// 取得某个 sqlId 对应配置的全部参数名
SqlToyConfig config = lightDao.getSqlToyConfig("report_sql_id", SqlType.SELECT);
String[] paramNames = config.getFullParamNames();
// 据此从报表条件 Map 中挑选/组装实际传参，再交给 sqltoy 执行
```

## 三、设计理念

> 有时候适度灵活一下，中间加一个过程转化一下就可以了。sqltoy 作为基础框架，不会把接口提供得过于泛滥而对常规开发人员形成干扰（"左也行、右也行"反而会让开发蒙圈）。把 SQL 托管、参数对齐、方言适配这些"脏活"交给框架，平台层只需专注业务编排。

## 四、相关

- SQL 配置驱动（报表/API 服务）的实战写法见[常见 SQL 案例](../query/sql_showcase.md)。
- 配置参数总览见[sqltoy 配置参数](../config/sqltoy_config.md)。
