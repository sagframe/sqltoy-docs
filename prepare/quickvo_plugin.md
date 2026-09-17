# quickvo-maven-plugin

除了独立运行 quickvo（见 [quickvo 代码生成工具](quickvo.md)），更推荐用 **quickvo-maven-plugin** 把代码生成集成进 Maven 构建，一条命令即可根据数据库表生成/更新 POJO 与 VO。

- 项目地址：https://gitee.com/sagacity/maven-quickvo-plugin （完整配置参见其 README）

## 一、在 pom.xml 中配置插件

```xml
<plugin>
    <groupId>com.sagframe</groupId>
    <artifactId>quickvo-maven-plugin</artifactId>
    <version>1.0.22</version>
    <configuration>
        <configFile>./src/main/resources/quickvo.xml</configFile>
        <baseDir>${project.basedir}</baseDir>
    </configuration>
    <dependencies>
        <!-- 放入对应数据库驱动 -->
        <dependency>
            <groupId>com.mysql</groupId>
            <artifactId>mysql-connector-j</artifactId>
            <version>${mysql.version}</version>
        </dependency>
    </dependencies>
</plugin>
```

## 二、编写 quickvo.xml

在 `src/main/resources` 下创建 `quickvo.xml`。它可以直接复用项目的 `application.yml` 中的数据源配置（通过 `<property file>` 引入 + `${}` 引用）：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<quickvo xmlns="http://www.sagframe.com/schema/quickvo"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.sagframe.com/schema/quickvo http://www.sagframe.com/schema/sqltoy/quickvo.xsd">
    <!-- 引入 db 配置文件，后续可用 ${} 引用其中的值 -->
    <property file="src/main/resources/application.yml" />
    <property name="project.version" value="1.0.0" />
    <property name="project.name" value="sqltoy-helloworld" />
    <!-- 项目默认包路径 -->
    <property name="project.package" value="com.sqltoy.helloworld" />

    <!-- 数据库定义，这里也可直接写具体值 -->
    <datasource name="helloworld" url="${spring.datasource.url}"
        driver="com.mysql.cj.jdbc.Driver" schema="${spring.datasource.username}"
        username="${spring.datasource.username}" password="${spring.datasource.password}" />

    <!-- dist: 生成代码存放路径(相对 pom 中 baseDir); encoding: 文件编码 -->
    <tasks dist="src/main/java" encoding="UTF-8">
        <!-- 可配置多个 task，把 pojo 生成到不同包路径; include 用正则匹配表名 -->
        <task datasource="helloworld" author="zhongxuchen" include="^SQLTOY_\w+" active="true">
            <!-- entity 生成 pojo; substr 去掉表名前缀; name 用 #{subName} 占位; lombok-chain 生成链式 set -->
            <entity package="${project.package}.entity" substr="Sqltoy" name="#{subName}" lombok-chain="true" />
            <!-- vo 生成 dto/vo -->
            <vo package="${project.package}.dto" lombok-chain="true" substr="Sqltoy" name="#{subName}VO" />
        </task>
    </tasks>
</quickvo>
```

常用配置说明：

| 配置 | 说明 |
| --- | --- |
| `<property file>` | 引入外部配置文件（如 application.yml），之后可用 `${key}` 引用 |
| `<datasource>` | 数据库连接；`schema`/`catalog` 在多实例库下务必正确配置 |
| `<tasks dist encoding>` | 生成代码的根路径与编码 |
| `<task include active>` | `include` 用正则匹配要生成的表（如 `^SQLTOY_\w+`），`active` 是否启用 |
| `<entity>` / `<vo>` | 分别生成 POJO 与 DTO/VO；`package` 目标包，`substr` 去除表名前缀，`name` 类名模板（`#{subName}` 为去前缀后的表名），`lombok-chain` 生成链式 set |

> 主键策略（`primary-key`）、级联（`cascade`）、类型映射（`type-mapping`）、swagger 注解等更多配置项，参见 [quickvo 代码生成工具](quickvo.md) 与官方 README。

## 三、执行生成

在项目根路径下执行：

```bash
mvn quickvo:quickvo
```

执行后：

- `src/main/java/com/sqltoy/helloworld/dto/` 下生成 `OrderInfoVO.java`；
- `src/main/java/com/sqltoy/helloworld/entity/` 下生成 `OrderInfo.java`，包含 `@Entity`、`@Id`、`@Column` 等描述对象与表关系的注解。

生成的 POJO 形如：

```java
@Data
@Accessors(chain = true)
@Entity(tableName="sqltoy_order_info", comment="sqltoy订单信息演示表", pk_constraint="PRIMARY")
public class OrderInfo implements Serializable {
    private static final long serialVersionUID = 7200696852961513069L;
/*---begin-auto-generate-don't-update-this-area--*/
    /** 订单编号 */
    @Id(strategy="generator", generator="org.sagacity.sqltoy.plugins.id.impl.NanoTimeIdGenerator")
    @Column(name="ORDER_ID", comment="订单编号", length=32L, type=java.sql.Types.VARCHAR,
            nativeType="VARCHAR", nullable=false)
    private String orderId;
    // ... 其余字段
/*---end-auto-generate-don't-update-this-area--*/
}
```

> **⚠️** `begin-auto-generate` 与 `end-auto-generate` 之间的内容由 quickvo 自动生成，**请勿手工修改**（重新生成会覆盖）；扩展属性/方法请写在区间之外。

完整建项目→生成→查询流程见 [helloworld 快速上手](../quickstart/helloworld.md)。
