# 多数据源与事务

sqltoy 本身不绑定数据源，多数据源可直接复用社区成熟的 **dynamic-datasource**（baomidou）方案：`@DS` 注解切换数据源、`@Transactional` 处理单库事务、`@DSTransactional` 把多个数据源的操作纳入同一事务。

> 本文整理自官方演示项目：<https://gitee.com/sagacity/sqltoy-showcase/tree/master/trunk/sqltoy-dynamic-datasource>（演示项目已升级至 **sqltoy 6.0.1 + Spring Boot 4.0.1**，本文示例与之一致）

## 一、引入依赖

```xml
<!-- dynamic-datasource（spring-boot3 对应 starter，在 Spring Boot 4.0.1 下可用） -->
<dependency>
    <groupId>com.baomidou</groupId>
    <artifactId>dynamic-datasource-spring-boot3-starter</artifactId>
    <version>4.5.0</version>
</dependency>
<!-- 连接池（以 druid 为例） -->
<dependency>
    <groupId>com.alibaba</groupId>
    <artifactId>druid-spring-boot-3-starter</artifactId>
    <version>1.2.28</version>
</dependency>
```

> [!WARNING]
> 使用 druid 时需**排除其自动配置**，否则与 dynamic-datasource 冲突：
> `@SpringBootApplication(exclude = DruidDataSourceAutoConfigure.class)`

## 二、配置多数据源

`primary` 指定默认数据源；`datasource` 下声明各个库；sqltoy 通过 `defaultDataSource` 指定默认库：

```yaml
spring:
    datasource:
        dynamic:
            primary: datasourceA          # 默认数据源
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
            druid:                        # 连接池公共配置
                initial-size: 5
                min-idle: 5
                maxActive: 20
                validationQuery: SELECT 1 FROM DUAL
                testWhileIdle: true
    sqltoy:
        # 注意前缀是 spring.sqltoy. ，不要写成 sqltoy. 导致无法加载
        sqlResourcesDir: classpath:com/sqltoy/dyndatasource
        debug: true
        # 指定 sqltoy 默认数据源
        defaultDataSource: datasourceA
```

## 三、使用 @DS 切换数据源

在 Service 方法上用 `@DS("数据源名称")` 切换，sqltoy 的操作会路由到对应库执行：

```java
@Service
public class OrderInfoServiceImpl implements OrderInfoService {
	@Autowired
	private LightDao lightDao;

	@Override
	@DS("datasourceA")     // 切换到 A 库
	public long saveLocalAOrders(List<OrderInfoVO> orderInfoVOs) {
		return lightDao.saveAll(orderInfoVOs);
	}

	@Override
	@DS("datasourceB")     // 切换到 B 库
	public long saveLocalBOrders(List<OrderInfoVO> orderInfoVOs) {
		return lightDao.saveAll(orderInfoVOs);
	}
}
```

- `primary` 指定的默认数据源**无需** `@DS` 注解；
- `@DS` 也可标注在类上，对整个类的操作生效。

## 四、事务处理

**单库事务**：正常使用 Spring 的 `@Transactional`（primary 数据源无需额外指定）：

```java
@Transactional
public void executeSql(String sql) {
	lightDao.executeSql(sql, MapKit.map());
}
```

**跨库事务**：使用 dynamic-datasource 提供的 `@DSTransactional`，把多个数据源的操作纳入同一事务——任一失败整体回滚：

```java
@Service
public class DynamicServiceImpl implements DynamicService {

	@Autowired
	private OrderInfoService orderInfoService;

	/**
	 * A、B 两个库的操作纳入同一事务
	 */
	@Override
	@DSTransactional
	public void saveOrder(List<OrderInfoVO> orderInfoVOAs, List<OrderInfoVO> orderInfoVOBs) {
		orderInfoService.saveLocalAOrders(orderInfoVOAs);   // 写 A 库
		orderInfoService.saveLocalBOrders(orderInfoVOBs);   // 写 B 库
	}
}
```

## 五、其他多数据源方式

| 方式 | 说明 |
| --- | --- |
| 多个 LightDao | 定义多个 `LightDao` bean 分别注入不同 dataSource，Service 中按 bean 名称引入 |
| 查询级切换 | `QueryExecutor.dataSource(...)` 与链式 `.dataSource(...)`（见 [Link 链式操作](../query/link_api.md)） |
| xml 指定 | `<sql dataSource="...">` 在单条 SQL 上指定数据源（见[动态 SQL 规范](../query/dynamic_sql.md)） |
| 多库事务(JTA) | 结合 JTA 实现，参见 sqltoy-sharding 演示 |

> 更多常见问题（如分库分表为什么不支持跨库 join 分页、与其他 ORM 组合使用等）见 [FAQ](../faq/faq.md)。

> 🎬 完整示例源码：演示项目 `sqltoy-showcase` 的 `DynamicServiceImpl.java`（@DSTransactional 跨库事务）与 `OrderInfoServiceImpl.java`（@DS 切换数据源）。

