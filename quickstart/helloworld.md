# 学习sqltoy-orm的基本原则
* 一定不要带入mybatis(plus)等开源项目的思维习惯
* 用显式和直接的思维来看待和学习sqltoy即可

# 快速搭建sqltoy项目的步骤

## 1、创建一个springboot项目，并配置好数据源
## 2、引入sqltoy的jar，在pom.xml中引入sqltoy-orm-spring-starter
## 3、引入通过数据库表生成pojo/dto的插件quickvo
## 4、创建表:sqltoy_order_info
## 5、执行quickvo，生产pojo
## 6、创建一个service和单元测试类