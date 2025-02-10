# sqltoy查询简介
* 1、sqltoy查询支持常规查询、分页查询、取top、取随机记录、校验数据唯一性
* 2、sqltoy的查询支持xml中写sql、java代码中直接传sql和第三方提供的lambda模式插件

## sqltoy动态查询sql编写原理
注意:这里是用xml做介绍，并不代表只能用xml

* 1、sqltoy通过filters标签将mybatis中sql语句中间的if等逻辑剥离出来，从而保障了sql语句的整洁性
* 2、sqltoy的配置里面隐藏了默认的blank-to-null="true"属性
* 3、#[]表示条件片段是动态的，必要条件不用加#[]
* 4、#[and t.name like :name and t.status=:status] 逻辑就是其中只要有一个参数为null，整个片段就被剔除
* 5、#[]作用就比较单纯标记sql逻辑的开始和截至位置
* 6、#[t.type=:type #[and t.amt>:amt and t.quantity>:quantity]]支持多层嵌套
* 7、必要条件，当参数为null时会自动转is null或 is not null
* 8、#标记恰巧是mysql等数据库的注释，所以可以在客户端里面直接执行

```xml

<!-- 隐藏了blank-to-null="true" <sql id="show_case" blank-to-null="true">-->
<sql id="show_case">
<filters>
   <!-- 通过filters中的标记对条件参数做前置规整处理 -->
   <eq params="status" value="-1" />
   <!-- 要关闭blank-to-null="true"两种做法：
      1、blank-to-null="false"
      2、通过blank标签对任意一个参数(包括不存在的)做一次处理，就自动关闭了blank-to-null的默认设置
   -->
   <blank params="anyParamNameIncludeNotExist"/>
</filters>
<value><![CDATA[
	select 	*
	from sqltoy_device_order_info t 
	where 
	      -- orderType为null会自动转成t.order_type is null
	      t.order_type=:orderType
	      and t.ORGAN_ID in (:authedOrganIds)
	      #[and t.status=:status]
	      #[and t.ORDER_ID=:orderId]
	      #[and t.TRANS_DATE>=:beginAndEndDate[0]]
	      #[and t.TRANS_DATE<:beginAndEndDate[1]]  
          #[and (t.TECH_GROUP,t.PROD_GROUP) in (:techGroups,:prodGroups)]
	]]></value>
</sql>

```