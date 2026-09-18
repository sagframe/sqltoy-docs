# Multi-Datasource & Transactions

sqltoy itself is not bound to any datasource. For multiple datasources you can directly reuse the mature community **dynamic-datasource** (baomidou) solution: the `@DS` annotation for datasource switching, `@Transactional` for single-database transactions, and `@DSTransactional` to bring operations across multiple datasources into the same transaction.

> This article is adapted from the official demo project: <https://gitee.com/sagacity/sqltoy-showcase/tree/master/trunk/sqltoy-dynamic-datasource> (the demo project has been upgraded to **sqltoy 6.0.1 + Spring Boot 4.0.1**, and the examples in this article are consistent with it)

## 1. Add Dependencies

```xml
<!-- dynamic-datasource (spring-boot3 starter, works under Spring Boot 4.0.1) -->
<dependency>
    <groupId>com.baomidou</groupId>
    <artifactId>dynamic-datasource-spring-boot3-starter</artifactId>
    <version>4.5.0</version>
</dependency>
<!-- Connection pool (druid as an example) -->
<dependency>
    <groupId>com.alibaba</groupId>
    <artifactId>druid-spring-boot-3-starter</artifactId>
    <version>1.2.28</version>
</dependency>
```

> [!WARNING]
> When using druid you must **exclude its auto-configuration**, otherwise it conflicts with dynamic-datasource:
> `@SpringBootApplication(exclude = DruidDataSourceAutoConfigure.class)`

## 2. Configure Multiple Datasources

`primary` specifies the default datasource; individual databases are declared under `datasource`; sqltoy specifies its default database via `defaultDataSource`:

```yaml
spring:
    datasource:
        dynamic:
            primary: datasourceA          # default datasource
            datasource:
                datasourceA:
                    url: jdbc:mysql://127.0.0.1:3306/dyndatasourcea?useUnicode=true&characterEncoding=utf-8&serverTimezone=GMT%2B8&useSSL=false
                    username: dyndatasourcea
                    password: dyndatasourcea
                    driver-class-name: com.mysql.cj.jdbc.Driver
                datasourceB:
                    url: jdbc:mysql://127.0.0.1:3306/dyndatasourceb?useUnicode=true&characterEncoding=utf-8&serverTimezone=GMT%2B8&useSSL=false
                    username: dyndatasourceb
                    password: dyndatasourceb
                    driver-class-name: com.mysql.cj.jdbc.Driver
            druid:                        # common connection pool settings
                initial-size: 5
                min-idle: 5
                maxActive: 20
                validationQuery: SELECT 1 FROM DUAL
                testWhileIdle: true
    sqltoy:
        # Note the prefix is spring.sqltoy. ; do not write it as sqltoy. or the configuration will not be loaded
        sqlResourcesDir: classpath:com/sqltoy/dyndatasource
        debug: true
        # Specify sqltoy's default datasource
        defaultDataSource: datasourceA
```

## 3. Switch Datasources with @DS

Use `@DS("datasource name")` on Service methods, and sqltoy operations are routed to the corresponding database:

```java
@Service
public class OrderInfoServiceImpl implements OrderInfoService {
	@Autowired
	private LightDao lightDao;

	@Override
	@DS("datasourceA")     // switch to database A
	public long saveLocalAOrders(List<OrderInfoVO> orderInfoVOs) {
		return lightDao.saveAll(orderInfoVOs);
	}

	@Override
	@DS("datasourceB")     // switch to database B
	public long saveLocalBOrders(List<OrderInfoVO> orderInfoVOs) {
		return lightDao.saveAll(orderInfoVOs);
	}
}
```

- The default datasource specified by `primary` does **not** need the `@DS` annotation;
- `@DS` can also be placed on the class, taking effect for all operations of the whole class.

## 4. Transaction Handling

**Single-database transaction**: use Spring's `@Transactional` as usual (no extra specification is needed for the primary datasource):

```java
@Transactional
public void executeSql(String sql) {
	lightDao.executeSql(sql, MapKit.map());
}
```

**Cross-database transaction**: use `@DSTransactional` provided by dynamic-datasource to bring operations across multiple datasources into the same transaction — if any of them fails, everything rolls back:

```java
@Service
public class DynamicServiceImpl implements DynamicService {

	@Autowired
	private OrderInfoService orderInfoService;

	/**
	 * Operations on databases A and B are brought into the same transaction
	 */
	@Override
	@DSTransactional
	public void saveOrder(List<OrderInfoVO> orderInfoVOAs, List<OrderInfoVO> orderInfoVOBs) {
		orderInfoService.saveLocalAOrders(orderInfoVOAs);   // write to database A
		orderInfoService.saveLocalBOrders(orderInfoVOBs);   // write to database B
	}
}
```

## 5. Other Multi-Datasource Approaches

| Approach | Description |
| --- | --- |
| Multiple LightDao beans | Define multiple `LightDao` beans, each injected with a different dataSource, and reference them by bean name in Services |
| Query-level switching | `QueryExecutor.dataSource(...)` and the chained `.dataSource(...)` (see [Link Chain API](../query/link_api.md)) |
| Specified in xml | `<sql dataSource="...">` specifies the datasource for a single SQL (see [Dynamic SQL Guide](../query/dynamic_sql.md)) |
| Multi-database transaction (JTA) | Implemented in combination with JTA; see the sqltoy-sharding demo |

> For more common questions (such as why sharding does not support cross-database join pagination, or how to combine sqltoy with other ORM frameworks), see the [FAQ](../faq/faq.md).

> 🎬 Full example source code: `DynamicServiceImpl.java` (@DSTransactional cross-database transaction) and `OrderInfoServiceImpl.java` (@DS datasource switching) in the demo project `sqltoy-showcase`.
