create table SQLTOY_DICT_DETAIL
(
   DICT_KEY             varchar(50) not null  comment '字典KEY',
   DICT_TYPE            varchar(50) not null  comment '字典类型代码',
   DICT_NAME            varchar(200) not null  comment '字典值',
   SHOW_INDEX           numeric(8) not null default 1  comment '显示顺序',
   UPDATE_BY            varchar(22) not null  comment '最后修改人',
   UPDATE_TIME          datetime not null  comment '最后修改时间',
   STATUS               decimal(1) not null default 1  comment '状态',
   primary key (DICT_KEY, DICT_TYPE)
);

alter table SQLTOY_DICT_DETAIL comment '字典明细表';

create table SQLTOY_DICT_TYPE
(
   DICT_TYPE            varchar(50) not null  comment '字典类型代码',
   DICT_TYPE_NAME       varchar(100) not null  comment '字典类型名称',
   COMMENTS             varchar(500)  comment '说明',
   SHOW_INDEX           numeric(8) not null default 1  comment '显示顺序',
   CREATE_BY            varchar(22) not null  comment '创建人',
   CREATE_TIME          datetime not null  comment '创建时间',
   UPDATE_BY            varchar(22) not null  comment '最后修改人',
   UPDATE_TIME          datetime not null  comment '最后修改时间',
   STATUS               decimal(1) not null default 1  comment '状态',
   primary key (DICT_TYPE)
);

alter table SQLTOY_DICT_TYPE comment '字典分类表';

create table SQLTOY_ORGAN_INFO
(
   ORGAN_ID             varchar(22) not null  comment '机构ID',
   ORGAN_NAME           varchar(100) not null  comment '机构名称',
   ORGAN_CODE           varchar(20) not null  comment '机构代码',
   COST_NO              varchar(20)  comment '成本中心代码',
   ORGAN_PID            varchar(22) not null  comment '父机构ID',
   NODE_ROUTE           varchar(200)  comment '节点路径',
   NODE_LEVEL           numeric(1)  comment '节点等级',
   IS_LEAF              numeric(1)  comment '是否叶子节点',
   SHOW_INDEX           numeric(8) not null default 1  comment '显示顺序',
   CREATE_BY            varchar(22) not null  comment '创建人',
   CREATE_TIME          datetime not null  comment '创建时间',
   UPDATE_BY            varchar(22) not null  comment '最后修改人',
   UPDATE_TIME          datetime not null  comment '最后修改时间',
   STATUS               decimal(1) not null default 1  comment '状态',
   primary key (ORGAN_ID)
);

alter table SQLTOY_ORGAN_INFO comment '机构信息表';

INSERT INTO SQLTOY_DICT_TYPE
(`DICT_TYPE`, `DICT_TYPE_NAME`, `COMMENTS`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('ORDER_TYPE', '订单类型', '订单类型', 3, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);

INSERT INTO SQLTOY_DICT_DETAIL
(`DICT_KEY`, `DICT_TYPE`, `DICT_NAME`, `SHOW_INDEX`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('PO', 'ORDER_TYPE', '采购订单', 1, 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_DICT_DETAIL
(`DICT_KEY`, `DICT_TYPE`, `DICT_NAME`, `SHOW_INDEX`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('SO', 'ORDER_TYPE', '销售订单', 2, 'S0001', '2025-02-05 16:47:01.000', 1);

INSERT INTO SQLTOY_ORGAN_INFO 
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100001', 'X科技创新集团有限公司', '100001', NULL, '-1', '-1,100001,', 1, 0, 1, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100002', '总经理办公室', '100002', NULL, '100001', '-1,100001,100002,', 2, 1, 2, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100003', '人力资源部', '100003', NULL, '100001', '-1,100001,100003,', 2, 1, 3, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100004', '财务部', '100004', NULL, '100001', '-1,100001,100004,', 2, 1, 4, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100005', '生物医药研发中心', '100005', NULL, '100001', '-1,100001,100005,', 2, 1, 5, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100006', '智能设备研发中心', '100006', NULL, '100001', '-1,100001,100006,', 2, 1, 6, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100007', '信息化研发中心', '100007', NULL, '100001', '-1,100001,100007,', 2, 1, 7, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100008', '新动力研发中心', '100008', NULL, '100001', '-1,100001,100008,', 2, 0, 8, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100009', '新能源研究院', '100009', NULL, '100008', '-1,100001,100008,100009,', 3, 1, 9, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100010', '发动机研究院', '100010', NULL, '100008', '-1,100001,100008,100010,', 3, 1, 10, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
INSERT INTO SQLTOY_ORGAN_INFO
(`ORGAN_ID`, `ORGAN_NAME`, `ORGAN_CODE`, `COST_NO`, `ORGAN_PID`, `NODE_ROUTE`, `NODE_LEVEL`, `IS_LEAF`, `SHOW_INDEX`, `CREATE_BY`, `CREATE_TIME`, `UPDATE_BY`, `UPDATE_TIME`, `STATUS`)
VALUES('100011', '后勤保障部', '100011', NULL, '100001', '-1,100001,100011,', 2, 1, 11, 'S0001', '2025-02-05 16:47:01.000', 'S0001', '2025-02-05 16:47:01.000', 1);
