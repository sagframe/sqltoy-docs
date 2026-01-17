# SQL查询功能


## lightDao API

### 前提：模板SQL

```xml
<sql id="sys_log_find_list">
    <value>
        <![CDATA[
        select *
        from sys_log
        ]]>
    </value>
</sql>
```

#### findOne 查找单个记录

```java
SysLog sysLog = lightDao.findOne("sys_log_findlist", new SysLog(), SysLog.class);
```

#### find 查找列表

```java
List<SysLog> list = lightDao.find("sys_log_find_list", new SysLog(), SysLog.class);
```

#### findEntity 实体查询

```java
List<SysLog> list = lightDao.findEntity(SysLog.class, EntityQuery.create().names("operator").values("112233"));
```

#### findPage 分页查询

```java
Page<SysLog> page = lightDao.findPage(new Page<>(1, 10), "sys_log_find_list", new SysLog(), SysLog.class);
```

#### findPageEntity 分页实体查询

```java
Page<SysLog> page = lightDao.findPageEntity(new Page<>(1, 10), SysLog.class, EntityQuery.create().names("operator").values("112233"));
```

#### findTop 查找N条记录

```java
List<SysLog> list = lightDao.findTop("sys_log_find_list", new SysLog(), SysLog.class, 12);
```

#### findRandom 随机查找N条记录

```java
List<SysLog> list = lightDao.findRandom("sys_log_find_list", new SysLog(), SysLog.class, 12);
```
