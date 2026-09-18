# Why common fields need unified assignment

* Regular business logic needs auditing:
  1) when a record is created, maintain the initial created-by and create-time;
  2) every modification maintains updated-by and update-time;
  3) when updating, the front end often sends back the previous values, so a forced overwrite is required.
  Therefore tables are usually designed with 4 standard columns: create_by / create_time / update_by / update_time.
  Assigning them by hand in code is repetitive and error-prone —
  the framework should handle it uniformly!
  Another key value: when updating, updated-by / update-time are maintained automatically (with forced overwrite of last-update-time where needed), **laying the groundwork for data auditing and update-time-based incremental ETL** — as long as unified assignment is in place, incremental extraction can rely on update_time directly, with no extra bookkeeping.

## Implementing the sqltoy common-field handler

* 1. SqlToy provides the standard interface: org.sagacity.sqltoy.plugins.IUnifyFieldsHandler
  Taking creation as an example, the assignment logic is:
  1) fields that don't exist on the object are skipped automatically (object CRUD knows the real field names);
  2) elastic assignment: if e.g. createBy already has a value it is kept as-is.

```java
  // logic sketch:
  if(entity.getCreateBy()!=null){entity.setCreateBy(unifyCreateMap.get("createBy"));}
```

* 2. Register the handler in application.yml

```yml
spring:
    sqltoy:
        unifyFieldsHandler: com.sqltoy.plugins.SqlToyUnifyFieldsHandler
```

* 3. The SqlToyUnifyFieldsHandler code

```java
package com.sqltoy.plugins;

import java.time.LocalDateTime;
import java.util.Map;

import org.sagacity.sqltoy.model.IgnoreCaseSet;
import org.sagacity.sqltoy.model.MapKit;
import org.sagacity.sqltoy.plugins.IUnifyFieldsHandler;

/**
 * @project sqltoy-helloworld
 * @description common-field auto-fill example
 * @author zhongxuchen <a href="mailto:zhongxuchen@gmail.com">contact</a>
 * @version v1.0,Date:2018-01-18
 */
public class SqlToyUnifyFieldsHandler implements IUnifyFieldsHandler {
	private String defaultUserName = "system-auto";

	 /**
	  * Fields and values assigned on creation (elastic: values already set by the caller win; nulls get filled)
	  */
	 public Map<String, Object> createUnifyFields() {
		LocalDateTime nowTime = LocalDateTime.now();
		// get the current user
		String userId = getUserId();
		// non-existent fields are skipped automatically, e.g. you may list both createBy and createdBy
		return MapKit.keys("createBy", "createTime", "updateBy", "updateTime", "enabled").values(userId, nowTime,
					userId, nowTime, 1);
	 }

	/**
	 * Fields and values assigned on update (elastic)
	 */
	@Override
	public Map<String, Object> updateUnifyFields() {
		return MapKit.keys("updateBy", "updateTime").values(getUserId(), LocalDateTime.now());
	}

	/**
	 * Force-updated fields (usually the updateTime property)
	 */
	@Override
	public IgnoreCaseSet forceUpdateFields() {
		IgnoreCaseSet forceUpdateFields = new IgnoreCaseSet();
		forceUpdateFields.add("updateTime");
		return forceUpdateFields;
	}

	/**
	 * Get the current user id
	 */
	private String getUserId() {
		// in real projects the current user is usually kept in a ThreadLocal set by a Filter,
		// e.g. with spring-security
		// return (SpringSecurityUtils.getCurrentUser() != null) ? SpringSecurityUtils.getCurrentUser().getId() : defaultUserName;
		return defaultUserName;
	}
}
```

## Unit test verifying the auto-fill

```java
@SpringBootTest
public class OrderInfoServiceTest {
	@Autowired
	OrderInfoService orderInfoService;
	
	@Test
	public void testCreateOrderInfo() {
		OrderInfoVO orderInfoVO = new OrderInfoVO();
		orderInfoVO.setOrderType("PO");
		orderInfoVO.setOrganId("T001");
		orderInfoVO.setProductCode("P0001");
		orderInfoVO.setPrice(BigDecimal.valueOf(100));
		orderInfoVO.setQuantity(BigDecimal.valueOf(100));
		orderInfoVO.setTotalAmt(BigDecimal.valueOf(10000));
		orderInfoVO.setUom("KG");
		orderInfoVO.setStaffCode("S0001");
		orderInfoVO.setStatus(1);
		// with SqlToyUnifyFieldsHandler registered there is no need to set:
		// orderInfoVO.setCreateBy("S0001");
		// orderInfoVO.setCreateTime(LocalDateTime.now());
		// orderInfoVO.setUpdateBy("S0001");
		// orderInfoVO.setUpdateTime(LocalDateTime.now());
		orderInfoService.createOrderInfo(orderInfoVO);
	}
}
```
