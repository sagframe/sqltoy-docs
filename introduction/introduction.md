sqltoy-orm是一个基于Java语言实现，融合JPA和最佳原生sql查询的ORM框架，其发展历程:
* 2004~2008:以SqlUtils、DBUtils形式融合在hibernate的BaseDaoSupport中提供一些原生分页、存储过程调用封装而存在。
* 2008年末:在思考如何应对多变的查询需求时，一个偶然的灵感发现了编写动态条件查询sql的合理方式，构建了sqltoy小组件jar
* 2009~2011年:作为hibernate(jpa)的查询辅助，在项目实践中逐步融入了快速分页、缓存翻译等特性
* 2012年:因考虑jpa的部分不足以及扩展的灵活性，扩展了类似JPA的对象化CRUD，从而正式形成sqltoy-orm1.0
* 2014年:彻底分离了不同数据库方言的逻辑实现,并实现了sql函数在不同数据库下自动转换功能，发布sqltoy-orm2.0
* 2015年:对代码进行了优化，完成对分库分表的支持，发布sqltoy-orm3.0
* 2016~2017:增强了分页功能，加入了分页优化器(并行+缓存count)，并支持elasticsearch和mongodb的查询功能，发布sqltoy-orm4.0
* 2018~2020:通过一个超大型SaaS化多租户项目的实践和完善，融入了多租户、支持springboot、并第一次发版到maven中央仓库，正式对外开源分享!