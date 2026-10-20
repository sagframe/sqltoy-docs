# Projects built on SqlToy

> To keep the SqlToy open-source ecosystem growing and better serve developers, you are welcome to register your use case.

## Demo Projects

- [sqltoy-helloworld](https://gitee.com/sagacity/sqltoy-helloworld): the official SqlToy quick-integration demo (zero-install on H2 — clone and run `mvn test`), companion to the [helloworld Quick Start](quickstart/helloworld.md) tutorial.

- [sqltoy-strict](https://gitee.com/sagacity/sqltoy-strict): demonstrates strict DTO/POJO layering with SqlToy.

- [sqltoy-quickstart](https://github.com/sagframe/sqltoy-quickstart): lesson-style quick-start project, runs zero-install (in-memory H2 + embedded Redis), from CRUD to cross-database SQL; Lesson 9 ships a docker-compose that verifies the same SQL against real PostgreSQL / SQL Server / Oracle / MySQL.

- [sqltoy-showcase](https://gitee.com/sagacity/sqltoy-showcase): full-feature demo project (single module; the former trunk sub-projects sqltoy-nosql / sqltoy-sharding / sqltoy-dynamic-datasource have been merged into it): sharding, multi-datasource, field encryption & masking, tree tables, FIFO dynamic cache, streaming & parallel queries, hierarchy packaging, MongoDB/Elasticsearch (real containers via Testcontainers), GraalVM native — every demo is a runnable test.

- [sqltoy-solon-demo](https://github.com/CoCoTeaNet/sqltoy-solon-demo): sample project integrating SqlToy ORM with the Solon framework.

## Extensions & Plugins

- [sqltoy-plus](https://gitee.com/gzghde/sqltoy-plus): an enhancement framework for SqlToy supporting object-oriented SQL operations and lambda expressions, making condition building more dynamic and flexible and simplifying multi-table joins.
  > **Since 6.0.8 the lambda condition API ships inside SqlToy core** (`org.sagacity.sqltoy.lambda`, see [Lambda Conditions](../query/lambda_query.md)); existing sqltoy-plus projects can follow the "migrating from sqltoy-plus" table on that page. The entry is kept for older projects.
- [sqltoy-idea-plugin](https://github.com/imyuyu/sqltoy-idea-plugin): an IntelliJ IDEA plugin providing SQL template highlighting, navigation and DAO method jump-to for the SqlToy framework.
- [sagacity-quickvo](https://github.com/sagframe/sagacity-quickvo): the official SqlToy code generator, implemented as a Maven plugin; generates Entity, VO (or DTO) and other Java objects straight from database tables.

## Admin Scaffold

- [CyreneAdmin](https://github.com/CoCoTeaNet/CyreneAdmin): a modern admin system with dual-framework support (Spring Boot and Solon), including permission management, user management, menu management and operation logs.
