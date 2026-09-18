# quickvo 代码生成工具

sqltoy 的 POJO/VO **不靠运行时反射猜测**，而是由 **quickvo** 工具连接数据库、根据表结构生成带注解的实体类。这样既保证对象与表精确对应，又让 SQL 编写时有完整的属性提示。

- 下载地址（releases）：https://gitee.com/sagacity/sagacity-quickvo/releases
- 完整配置范例参见 `sqltoy-quickstart` 项目 `tools` 目录下的 quickvo 配置。

## 一、工作原理

quickvo 是一个可执行 jar（`sagacity-quickvo.jar`），通过 `quickvo.bat`（Windows）或 `quickvo.sh`（Linux/Mac）启动：

```bat
:: quickvo.bat 核心语句
java -cp ./libs/* org.sagacity.quickvo.QuickVOStart quickvo.xml
```

- 将数据库驱动 jar 放入 `libs` 目录，quickvo 会自动加载驱动；
- 读取 `quickvo.xml` 连接数据库，利用 freemarker 模板生成 VO/POJO 类；
- Linux/Mac 上编写 `quickvo.sh` 时注意路径分隔符（反斜杠→正斜杠）。

## 二、quickvo.xml 配置要点

`quickvo.xml` 主要由 `property`（参数）、`datasource`（数据库）、`tasks/task`（生成任务）等部分组成。下面为独立运行时的结构示意（Maven 插件方式的完整配置见 [quickvo-maven-plugin](quickvo_plugin.md)）：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<quickvo xmlns="http://www.sagframe.com/schema/quickvo">
    <!-- property: 全局参数或参数文件，之后可用 ${} 引用 -->
    <property file="src/main/resources/application.yml" />
    <property name="project.package" value="com.demo" />

    <!-- datasource: 数据库连接信息（可直接写值，也可用 ${} 引用 property） -->
    <datasource name="demo" url="jdbc:mysql://localhost:3306/demo"
                driver="com.mysql.cj.jdbc.Driver" schema="demo"
                username="root" password="***" />

    <!-- tasks: dist 生成路径; task 用 include 正则匹配表; entity 生成 pojo, vo 生成 dto/vo -->
    <tasks dist="src/main/java" encoding="UTF-8">
        <task datasource="demo" author="dev" include="^SQLTOY_\w+" active="true">
            <entity package="${project.package}.entity" substr="Sqltoy" name="#{subName}" lombok-chain="true" />
            <vo package="${project.package}.dto" substr="Sqltoy" name="#{subName}VO" lombok-chain="true" />
        </task>
    </tasks>

    <!-- 还可配置: primary-key(主键策略)、cascade(主子表级联)、type-mapping(类型映射)、swagger(v3/v2/false) -->
</quickvo>
```

关键配置说明：

| 配置 | 说明 |
| --- | --- |
| `property` | 全局参数或参数文件（`file` 引入外部配置，`name`/`value` 定义参数） |
| `datasource` | 数据库连接；**多实例库务必正确配置 `schema` 或 `catalog`**（见下方注意事项） |
| `tasks` / `task` | `dist` 生成路径、`encoding` 编码；`task` 用 `include` 正则匹配表名、`active` 是否启用，可配多个 task 生成到不同包 |
| `entity` / `vo` | 分别生成 POJO 与 DTO/VO；`package` 目标包、`substr` 去表名前缀、`name` 类名模板（`#{subName}`）、`lombok-chain` 链式 set |
| `swagger` | 生成 swagger 注解：`v3`/`v2`/`false`（不生成） |
| `field.support.linked.set` | 开关：生成的 VO 中 set 方法是否返回自身（链式） |
| `primary-key` | 表主键策略；identity 类型无需配置。quickvo 会按主键类型/长度自动设置：`bigint`→snowflake，22 位字符→DefaultIdGenerator，26 位→NanoTimeIdGenerator |
| `cascade` | 级联操作配置：load 级联（如只加载有效子表）、update 级联（delete 无需配置，按主外键直接删子表）、`orderBy`（加载子表排序，如 `showIndex desc`） |
| `type-mapping` | 字段类型映射；`import-types` 可额外指定 VO 的 import 类型。若类型匹配不上，quickvo 会在日志中打印提示，据此补充 type-mapping |

> quickvo 5.0.1 起 entity 支持 **lombok**，并支持自定义 api-doc 框架。

## 三、生成结果与注解

一张表会生成 **AbstractVO + VO** 两个类，VO 继承 AbstractVO。sqltoy 通过注解解析 VO：

- `@Entity(tableName="sqltoy_dict_detail", pk_constraint="PRIMARY")`：对应具体表（`org.sagacity.sqltoy.config.annotation.Entity`）；
- `@SqlToyEntity`：标注 VO 检索时的精确定位——找到 `@SqlToyEntity` 后再找其父类，从而定位到真正与表对应的类，并检索 `@Id`、`@Column` 形成对象与表的完整映射；
- `@Id`、`@Column`：主键与字段映射。

quickvo 会把数据库表/字段注释一并写入 VO，便于阅读维护。

> [!WARNING]
> 请勿修改 VO 中"标记区间"内的内容（重新生成会覆盖）。如需扩展属性或 get/set 方法，请在该区间**之外**添加。

## 四、关键注意事项

**多实例数据库下字段重复/错乱**：当多个实例库中存在同名表（如 `SYS_STAFF_INFO`）时，生成的 VO 可能出现字段重复或混入其他库的字段。

解决办法：**正确配置数据源的 `schema` 或 `catalog`**（一般配置 `schema` 即可）。底层取表信息、取列信息都依赖该配置，配置错误会取到不属于当前库的表/字段。

## 五、严格 VO(DTO) 与 POJO(entity) 分层

中大型项目建议将对外交互的 VO/DTO 与持久层 POJO 严格分层，通过 quickvo 配置生成到不同包，并在业务中做 VO↔POJO 转换（参见[工具类：DTO 与 POJO 互转](../tools/utils.md)）。

- 分层示例项目：https://github.com/sagframe/sqltoy-strict

## 六、相关

- 把 quickvo 集成进 Maven 构建，见 [quickvo-maven-plugin](quickvo_plugin.md)。
- 主键策略详情见[主键策略介绍](../primarykey/sqltoy_primarykey.md)。
