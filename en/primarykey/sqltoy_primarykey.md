# Primary Key Strategies

## sqltoy's default primary-key strategy implementations (you can extend them yourself)

<img width="435" height="454" alt="image" src="https://github.com/user-attachments/assets/263a382a-0172-4064-a398-33c00fbbd4da" />

## The following primary-key strategies are supported

1. sequence: the database itself must have a sequence name defined; currently supported databases include oracle, postgresql, sqlserver, etc.
> Define the table's primary-key strategy in quickvo.xml

<img width="798" height="56" alt="image" src="https://github.com/user-attachments/assets/2215566f-d185-4d4c-be5f-0b0156a9354b" />

> The generated AbstractVO reflects the sequence strategy through the @Id() annotation

<img width="696" height="141" alt="image" src="https://github.com/user-attachments/assets/fcc1a6d2-81e3-442f-9945-359eb69e940f" />

2. identity: for the identity strategy, sqltoy requires no extra configuration in quickvo.xml; it automatically detects from the database whether it is identity-based.

3. default: a 22-digit ordered, non-repeating number: 13 digits of current milliseconds + 6 digits of nanoseconds + 3 digits of host ID. Implementation class:
org.sagacity.sqltoy.plugins.id.impl.DefaultIdGenerator
Example: 1592214184072221900219.

4. nanotime: a 26-digit ordered, non-repeating number, format: 15 digits: yyMMddHHmmssSSS + trailing 6 digits of nanoseconds + 2 digits (thread ID + random number) + 3 digits of host ID
5. snowflake: the snowflake algorithm, producing a 16-digit ordered, non-repeating number.
6. UUID: a 32-digit UUIDv7 (upgraded to the ordered UUIDv7 as of sqltoy 5.6.59)
7. ULID: a 26-character ordered value: 10-digit timestamp + 16 digits of random entropy; the project needs to include the following dependency

```xml
<dependency>
	<groupId>com.github.f4b6a3</groupId>
	<artifactId>ulid-creator</artifactId>
	<!-- adjust the version as needed -->
	<version>5.2.4</version>
</dependency>
```

8. redis: generates ordered primary keys centrally based on Redis; generally used for primary keys with a regular pattern, such as order numbers: year-month-day + several sequence digits.

> To generate primary keys via redis, sqltoy requires a RedisTemplate to be defined
> A redis primary key falls into the business-key category; the way to define it in quickvo.xml

<img width="806" height="222" alt="image" src="https://github.com/user-attachments/assets/7aa1da10-8e26-445d-a951-57f8ab7b48b0" />


## redis business key: the @BusinessId annotation and generateBizId

The redis strategy belongs to the **business key** category (e.g., an order number: year-month-day + several sequence digits). Besides configuring a single business key via quickvo / `@Id`, when a table involves **multiple business keys** (only a single one is supported at the configuration level), you can use the `@BusinessId` annotation plus the `generateBizId` API to generate and assign them yourself.

* 1. Declare the business-key strategy on a POJO field with `@BusinessId`

```java
/** Order number (business key) */
@BusinessId(signature = "HW@case(orderType,SALE,SC,BUY,PO)@day(yyMMdd)",
        generator = "org.sagacity.sqltoy.plugins.id.impl.RedisIdGenerator",
        length = 20, sequenceSize = 5, relatedColumns = {"orderType"})
private String orderId;
```

`@BusinessId` attributes:

| Attribute | Description |
| --- | --- |
| `signature` | Signature expression used for identification; supports macros such as `@case(name,v1,then1,v2,then2)`, `@day(yyMMdd)`, `@substr(name,start,length)` |
| `generator` | Implementation class of the primary-key generation strategy (e.g., the redis strategy `RedisIdGenerator`) |
| `length` / `sequenceSize` | Total length of the business key / number of trailing sequence digits (default -1 means the global configuration applies) |
| `relatedColumns` | Related columns that participate in key generation |
| `start` | Initial value of the sequence, default 1 |

* 2. Generate via LightDao's generateBizId

```java
// 1) Based on the @BusinessId strategy configured on the entity object, extract the property values to generate the business key
String orderId = lightDao.generateBizId(orderInfo);

// 2) Generate with dynamic parameters (business keys are managed in isolation per table; the signature supports the @case/@day/@substr macros)
String bizId = lightDao.generateBizId("sqltoy_order_info",
        "HW@case(orderType,SALE,SC,BUY,PO)@day(yyMMdd)",
        MapKit.map("orderType", "SALE"), null, 20, 5);

// 3) Simple form: unique signature + increment
long id = lightDao.generateBizId("ORDER", 1);
```

> 🎬 Fully runnable example: `BusinessIdAndDataVersionTest.java` in the demo project `sqltoy-showcase` (demonstrates the @BusinessId annotation usage; running it depends on Redis, and it is marked @Disabled as a reference implementation).

## Using a custom primary-key strategy

1. Custom primary-key strategy: implement the IdGenerator class
<img width="461" height="278" alt="image" src="https://github.com/user-attachments/assets/7cb0b9cf-3304-45e0-918a-b088f3ed8750" />

2. Configure it in quickvo.xml for specific tables (you can use regular expressions to configure them in batch)
<img width="838" height="143" alt="image" src="https://github.com/user-attachments/assets/337f16b7-3726-407c-97a9-74ff78029fd2" />

## Handling duplicate primary keys

When sqltoy's default, nanotime, and snowflake primary-key strategies are used to deploy multiple applications on a single IP server, duplicates can occur. The reason: by default the IP address is fetched to distinguish different workers. Solutions:
1. default, nanotime: java -Dsqltoy.server.id=112 (three digits)
2. snowflake: two parameters must be set, in numeric form and each smaller than 32
```shell
java -Dsqltoy.snowflake.workerId=11
java -Dsqltoy.snowflake.dataCenterId=20
```
