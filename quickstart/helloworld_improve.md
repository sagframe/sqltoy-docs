# 公共字段统一赋值背景
* 常规业务逻辑为了审计需要:  
  1)在单据创建时需要维护初始的:创建人、创建时间;  
  2)每次修改需要维护:修改人、修改时间  
  因此在数据库表设计时，往往需要统一设计4个字段:create_by\create_time\update_by\update_time  
  在代码层面每次手工给这些字段赋值就带来大量重复工作，且容易产生遗漏！  
  这就需要在框架层面提供统一的处理!
  
## sqltoy自定义公共字段赋值接口实现
* 1、sqltoy提供了标准接口:org.sagacity.sqltoy.plugins.IUnifyFieldsHandler  
  以创建为例，sqltoy统一字段赋值的逻辑:  
  1) 字段不存在，会自动跳过(对象化CRUD很方便判断实际字段名称)  
  2) 弹性赋值:比如字段:createBy已经赋值就会自动跳过
  
```java
  //伪代码逻辑: 
  if(entity.getCreateBy()!=null){entity.setCreateBy(unifyCreateMap.get("createBy"));}
```
* 2、自定义实现类:com.sqltoy.plugins.SqlToyUnifyFieldsHandler
* 3、在application.yml中配置sqltoy的公共字段处理类

```yml
spring:
    sqltoy:
        unifyFieldsHandler: com.sqltoy.plugins.SqlToyUnifyFieldsHandler
```


```java
package com.sqltoy.plugins;

import java.time.LocalDateTime;
import java.util.Map;

import org.sagacity.sqltoy.model.IgnoreCaseSet;
import org.sagacity.sqltoy.model.MapKit;
import org.sagacity.sqltoy.plugins.IUnifyFieldsHandler;

/**
 * @project sqltoy-helloworld
 * @description 统一字段赋值范例
 * @author zhongxuchen <a href="mailto:zhongxuchen@gmail.com">联系作者</a>
 * @version v1.0,Date:2018年1月18日
 */
public class SqlToyUnifyFieldsHandler implements IUnifyFieldsHandler {
	private String defaultUserName = "system-auto";

	 /**
	  * @TODO 设置创建记录时需要赋值的字段和对应的值(弹性模式:即以传递的值优先，为null再填充)
	  */
	 public Map<String, Object> createUnifyFields() {
		LocalDateTime nowTime = LocalDateTime.now();
		// 获取用户信息
		String userId = getUserId();
		// 字段不存在会自动跳过，如:createBy和createdBy,你可以两种都写上
		return MapKit.keys("createBy", "createTime", "updateBy", "updateTime", "enabled").values(userId, nowTime,
					userId, nowTime, 1);
	 }

	/**
	 * @TODO 设置修改记录时需要赋值的字段和对应的值(弹性)
	 */
	@Override
	public Map<String, Object> updateUnifyFields() {
		return MapKit.keys("updateBy", "updateTime").values(getUserId(), LocalDateTime.now());
	}

	/**
	 * @TODO 強制修改的字段(一般针对updateTime属性)
	 */
	@Override
	public IgnoreCaseSet forceUpdateFields() {
		IgnoreCaseSet forceUpdateFields = new IgnoreCaseSet();
		forceUpdateFields.add("updateTime");
		return forceUpdateFields;
	}

	/**
	 * @todo 获取当前用户Id信息
	 * @return
	 */
	private String getUserId() {
		// 实际项目一般通过ThreadLocal+Filter方式存放和获取当前用户信息
		// 比如spring-security
		// return (SpringSecurityUtils.getCurrentUser() != null) ? SpringSecurityUtils.getCurrentUser().getId() : defaultUserName;
		return defaultUserName;
	}
}
```
 