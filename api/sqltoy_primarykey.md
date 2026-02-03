# 主键策略介绍

## sqltoy默认的主键策略实现(可以自行扩展)

<img width="435" height="454" alt="image" src="https://github.com/user-attachments/assets/263a382a-0172-4064-a398-33c00fbbd4da" />

## 支持以下主键策略

1. sequence：数据库自身需要定义一个sequence名称，目前支持的数据库有oracle、postgresql、sqlserver等
> 在quickvo.xml中定义表的主键策略

<img width="798" height="56" alt="image" src="https://github.com/user-attachments/assets/2215566f-d185-4d4c-be5f-0b0156a9354b" />

> 产生的AbstractVO中@Id()注解体现sequence策略

<img width="696" height="141" alt="image" src="https://github.com/user-attachments/assets/fcc1a6d2-81e3-442f-9945-359eb69e940f" />

2. identity: identity策略sqltoy无需通过quickvo.xml中额外指定，会自动根据数据库判断出是否是identity。

3. default:22位有序不重复数字:13位当前毫秒+6位纳秒+3位主机ID实现类：
org.sagacity.sqltoy.plugins.id.impl.DefaultIdGenerator
例如: 1592214184072221900219.

4. nanotime:26位有序不重复数字，格式:15位:yyMMddHHmmssSSS+后6位纳秒+2位(线程Id+随机数)+3位主机ID

5. snowflake:雪花算法16位有序不重复数字。

6. UUID:32位UUID。

7. redis:基于redis进行统一生成有序主键，一般用于有规则的主键生成，如订单号:年月日+几位流水。

> sqltoy使用redis生成主键需要定义RedisTemplate
> redis主键属于业务主键范畴，在quickvo.xml中定义方式

<img width="806" height="222" alt="image" src="https://github.com/user-attachments/assets/7aa1da10-8e26-445d-a951-57f8ab7b48b0" />

## 使用自定义主键策略

1. 自定义主键策略：实现IdGenarator类
<img width="461" height="278" alt="image" src="https://github.com/user-attachments/assets/7cb0b9cf-3304-45e0-918a-b088f3ed8750" />

2. quickvo.xml 针对具体表(可以用正则表达式批量设置)进行设置
<img width="838" height="143" alt="image" src="https://github.com/user-attachments/assets/337f16b7-3726-407c-97a9-74ff78029fd2" />

## 主键重复处理

Sqltoy的default、nanotime、snowflake 三种主键策略在单个IP服务器上部署多个应用，就会出现重复现象，原理：默认会获取IP地址来区分不同的worker。解决方法：
1. default、nanotime：java -Dsqltoy.server.id=112(三位数字)
2. snowflakc：则需要设置2个参数，数字形式，且小于32
```shell
java -Dsqltoy.snowflake.workerId=11
java -Dsqltoy.snowflake.dataCenterId=20
```

