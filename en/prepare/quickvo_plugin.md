# quickvo-maven-plugin

Besides running quickvo standalone (see [quickvo Code Generator](quickvo.md)), the recommended approach is **quickvo-maven-plugin**, which integrates code generation into the Maven build — a single command generates/updates the POJO and VO classes from database tables.

> [!NOTE]
> Version **2.0.0** was a major refactoring of previous releases and has been tested against 19 databases (Oracle, DB2, SQL Server, MySQL, PostgreSQL, HANA, Kingbase, DM, openGauss, OceanBase, Doris, TiDB, StarRocks, ClickHouse, etc.). See the plugin repository README for the full feature list and configuration.

- Project home: https://gitee.com/sagacity/maven-quickvo-plugin (see its README for the full configuration)

## 1. Configure the Plugin in pom.xml

```xml
<plugin>
    <groupId>com.sagframe</groupId>
    <artifactId>quickvo-maven-plugin</artifactId>
    <version>2.0.0</version>
    <configuration>
        <configFile>./src/main/resources/quickvo.xml</configFile>
        <baseDir>${project.basedir}</baseDir>
    </configuration>
    <dependencies>
        <!-- add the driver for your database -->
        <dependency>
            <groupId>com.mysql</groupId>
            <artifactId>mysql-connector-j</artifactId>
            <version>${mysql.version}</version>
        </dependency>
    </dependencies>
</plugin>
```

## 2. Write quickvo.xml

Create `quickvo.xml` under `src/main/resources`. It can directly reuse the datasource configuration from the project's `application.yml` (imported via `<property file>` and referenced via `${}`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<quickvo xmlns="http://www.sagframe.com/schema/quickvo"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.sagframe.com/schema/quickvo https://sagframe.github.io/schema/quickvo.xsd">
    <!-- import the db config file; its values can be referenced later via ${} -->
    <property file="src/main/resources/application.yml" />
    <property name="project.version" value="1.0.0" />
    <property name="project.name" value="sqltoy-helloworld" />
    <!-- project default package -->
    <property name="project.package" value="com.sqltoy.helloworld" />

    <!-- database definition; concrete values can also be written here directly -->
    <datasource name="helloworld" url="${spring.datasource.url}"
        driver="com.mysql.cj.jdbc.Driver" schema="${spring.datasource.username}"
        username="${spring.datasource.username}" password="${spring.datasource.password}" />

    <!-- dist: where generated code goes (relative to baseDir in the pom); encoding: file charset -->
    <tasks dist="src/main/java" encoding="UTF-8">
        <!-- multiple tasks can be configured to generate pojo into different packages; include matches table names with a regex -->
        <task datasource="helloworld" author="zhongxuchen" include="^SQLTOY_\w+" active="true">
            <!-- entity generates pojo; substr strips the table-name prefix; name uses the #{subName} placeholder; lombok-chain generates chained setters -->
            <entity package="${project.package}.entity" substr="Sqltoy" name="#{subName}" lombok-chain="true" />
            <!-- vo generates dto/vo -->
            <vo package="${project.package}.dto" lombok-chain="true" substr="Sqltoy" name="#{subName}VO" />
        </task>
    </tasks>
</quickvo>
```

Common configuration:

| Configuration | Description |
| --- | --- |
| `<property file>` | Imports an external config file (e.g. application.yml); its values can then be referenced via `${key}` |
| `<datasource>` | Database connection; always configure `schema`/`catalog` correctly for multi-instance databases |
| `<tasks dist encoding>` | Root path and charset of the generated code |
| `<task include active>` | `include` matches the tables to generate with a regex (e.g. `^SQLTOY_\w+`); `active` enables/disables the task |
| `<entity>` / `<vo>` | Generate POJO and DTO/VO respectively; `package` is the target package, `substr` strips the table-name prefix, `name` is the class-name template (`#{subName}` is the table name with the prefix removed), `lombok-chain` generates chained setters |

> For more options such as primary key strategy (`primary-key`), cascade (`cascade`), type mapping (`type-mapping`), and swagger annotations, see [quickvo Code Generator](quickvo.md) and the official README.

## 3. Run the Generation

Execute in the project root:

```bash
mvn quickvo:quickvo
```

After execution:

- `OrderInfoVO.java` is generated under `src/main/java/com/sqltoy/helloworld/dto/`;
- `OrderInfo.java` is generated under `src/main/java/com/sqltoy/helloworld/entity/`, containing annotations such as `@Entity`, `@Id`, `@Column` that describe the object-to-table mapping.

The generated POJO looks like:

```java
@Data
@Accessors(chain = true)
@Entity(tableName="sqltoy_order_info", comment="sqltoy order info demo table", pk_constraint="PRIMARY")
public class OrderInfo implements Serializable {
    private static final long serialVersionUID = 7200696852961513069L;
/*---begin-auto-generate-don't-update-this-area--*/
    /** Order ID */
    @Id(strategy="generator", generator="org.sagacity.sqltoy.plugins.id.impl.NanoTimeIdGenerator")
    @Column(name="ORDER_ID", comment="Order ID", length=32L, type=java.sql.Types.VARCHAR,
            nativeType="VARCHAR", nullable=false)
    private String orderId;
    // ... remaining fields
/*---end-auto-generate-don't-update-this-area--*/
}
```

> [!WARNING]
> The content between `begin-auto-generate` and `end-auto-generate` is generated automatically by quickvo — **do not modify it manually** (it will be overwritten on regeneration). Put extension properties/methods outside the marked section.

For the complete create-project → generate → query workflow, see the [helloworld quick start](../quickstart/helloworld.md).
