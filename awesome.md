# 使用 Sqltoy 开源项目

> 为促进 Sqltoy 开源生态的持续发展，更好地服务广大开发者，欢迎大家登记 Sqltoy 在项目中的应用案例。

## 演示项目

- [sqltoy-helloworld](https://gitee.com/sagacity/sqltoy-helloworld)：sqltoy 快速集成演示（H2 零安装，clone 后 `mvn test` 即跑），配套教程见 [helloworld 快速上手](quickstart/helloworld.md)。

- [sqltoy-strict](https://gitee.com/sagacity/sqltoy-strict)：提供sqltoy 按照严格分层，dto、pojo 模式的项目演示。

- [sqltoy-quickstart](https://github.com/sagframe/sqltoy-quickstart)：课程式快速入门工程，零安装即可运行（H2 内存库 + 嵌入式 Redis），从 CRUD 到跨数据库 SQL；第 9 课配套 docker-compose 在 PostgreSQL/SQL Server/Oracle/MySQL 真库上验证同一套 SQL。

- [sqltoy-showcase](https://gitee.com/sagacity/sqltoy-showcase)：全功能演示工程（单模块，原 trunk 下的 sqltoy-nosql / sqltoy-sharding / sqltoy-dynamic-datasource 子项目已并入）：分库分表、多数据源、数据加解密与脱敏、树形表、FIFO 动态缓存、流式/并行查询、层次封装、MongoDB/Elasticsearch（Testcontainers 真容器）、GraalVM native——每个演示都是可直接运行的测试。

- [sqltoy-solon-demo](https://github.com/CoCoTeaNet/sqltoy-solon-demo)：Sqltoy ORM 框架集成到 Solon 的示例工程。

## 拓展插件

- [sqltoy-plus](https://gitee.com/gzghde/sqltoy-plus)：sqltoy增强框架,支持对象化sql操作，支持lamada表达式，使得条件拼装更加动态和灵活，简化多表关联操作。
  > **6.0.8 起 lambda 条件体系已内置到 sqltoy 核心**（`org.sagacity.sqltoy.lambda`，见 [Lambda 条件查询与更新](query/lambda_query.md)），sqltoy-plus 存量项目可按该页"自 sqltoy-plus 迁移对照"平滑切换；本条目保留供旧项目参考。
- [sqltoy-idea-plugin](https://github.com/imyuyu/sqltoy-idea-plugin)：一款 IntelliJ IDEA 插件，为 Sqltoy 框架提供 SQL 模板高亮、导航与 DAO 方法跳转等智能支持，提升开发效率。
- [sagacity-quickvo](https://github.com/sagframe/sagacity-quickvo)：Sqltoy 官方推出的代码生成工具，基于 Maven 插件实现，可从数据库表自动生成 Entity、VO（或 DTO）等 Java 对象。

## 后台管理

- [CyreneAdmin](https://github.com/CoCoTeaNet/CyreneAdmin)：CyreneAdmin 是一个现代化的后台管理系统，提供双框架支持（Spring Boot 和 Solon），集成了完善的权限管理、用户管理、菜单管理、操作日志等核心功能。
