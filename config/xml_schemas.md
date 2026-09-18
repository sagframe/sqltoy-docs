# XML Schema 配置指引

sqltoy 的三类 XML 配置文件均提供官方 XSD schema（托管在 GitHub：[sagframe/schema](https://github.com/sagframe/schema)）。配置正确后，在 IDEA 中编辑这些文件可获得**标签补全、属性提示与错误校验**。

## 三类配置文件与 schema 指向

| 配置文件 | 用途 | xmlns（命名空间，永远不变） | xsi:schemaLocation 中的文件位置 |
| --- | --- | --- | --- |
| `*.sql.xml` | sql / mql / eql 查询定义 | `http://www.sagframe.com/schema/sqltoy` | `https://sagframe.github.io/schema/sqltoy.xsd` |
| `sqltoy-translate.xml` | 缓存翻译配置 | `https://www.sagframe.com/schema/sqltoy-translate` | `https://sagframe.github.io/schema/sqltoy-translate.xsd` |
| `quickvo.xml` | quickvo 代码生成配置 | `http://www.sagframe.com/schema/quickvo` | `https://sagframe.github.io/schema/quickvo.xsd` |

> [!IMPORTANT]
> `xmlns` 是 schema 的身份标识，**不需要可访问、永远不要修改**；`xsi:schemaLocation` 的第二个地址只是"文件在哪"的提示。框架运行时**不会**联网读取 XSD，它只服务于 IDE 的补全与校验。

## 旧地址过渡说明

历史版本使用的是 `http://www.sagframe.com/schema/sqltoy/` 下的地址：

| 旧地址（仍可访问） | 新地址（推荐） |
| --- | --- |
| `http://www.sagframe.com/schema/sqltoy/sqltoy.xsd` | `https://sagframe.github.io/schema/sqltoy.xsd` |
| `http://www.sagframe.com/schema/sqltoy/sqltoy-translate.xsd` | `https://sagframe.github.io/schema/sqltoy-translate.xsd` |
| `http://www.sagframe.com/schema/sqltoy/quickvo.xsd` | `https://sagframe.github.io/schema/quickvo.xsd` |

针对存量文件：

- **不影响运行**：框架运行时不读取 XSD，带着旧地址的文件照常工作；
- **仅影响 IDE 体验**：旧地址为 http 协议、以 `application/octet-stream` 类型返回，部分网络环境或 IDEA 版本可能抓取失败，导致编辑时无法获得补全；
- **建议逐步替换**为新地址即可，无需一次性整改——新地址为 https + 标准 XML 类型，首次 Alt+Enter 抓取即可生效。

## 标准文件头（copy 即用）

**`*.sql.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<sqltoy xmlns="http://www.sagframe.com/schema/sqltoy"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.sagframe.com/schema/sqltoy https://sagframe.github.io/schema/sqltoy.xsd">

</sqltoy>
```

**`sqltoy-translate.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<sagacity xmlns="https://www.sagframe.com/schema/sqltoy-translate"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="https://www.sagframe.com/schema/sqltoy-translate https://sagframe.github.io/schema/sqltoy-translate.xsd">

</sagacity>
```

**`quickvo.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<quickvo xmlns="http://www.sagframe.com/schema/quickvo"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.sagframe.com/schema/quickvo https://sagframe.github.io/schema/quickvo.xsd">

</quickvo>
```

## IDEA 中启用补全与校验

1. 打开任一配置文件，把光标放到标红的地址上，按 **Alt+Enter** → 选择 **Fetch external resource**（抓取一次即可，IDEA 全局缓存共享，其他项目无需重复）；
2. 之后编辑文件即有标签/属性补全，写错标签名或属性名会即时标红；
3. 也可以在 `Settings | Languages & Frameworks | Schemas and DTDs` 中手动添加 URI 到 XSD 文件的映射。

## 相关页面

- [动态 SQL 编写规范](../query/dynamic_sql.md)：`*.sql.xml` 中 `<sql>` 元素与子标签的完整规范
- [缓存翻译使用](../quickstart/translates.md)：translate.xml 的配置与用法
- [quickvo 代码生成工具](../prepare/quickvo.md)：quickvo.xml 的配置要点
