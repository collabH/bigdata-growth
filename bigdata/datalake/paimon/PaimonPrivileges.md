# Manage Privileges

* Paimon提供一个基于catalog的权限系统，权限决定哪些用户可以对哪些对象执行哪些操作，因此可以以细粒度的方式管理表访问。目前，Paimon采用基于身份的访问控制(IBAC)权限模型，直接将权限分配给用户。

> 当前权限系统只能防止不是该表的用户访问该表，不能组织用户修改底层数据文件。

## 基础概念

### Object

* Object是可以授予访问权限的实体。除非获得许可，否则拒绝访问。
* Paimon中的权限系统有三种类型的Object:CATALOG、DATABASE和TABLE。Object具有逻辑层次结构，这与它们所表示的概念有关。例如：
  * 如果用户被授予catalog上的权限，那么他将对catalog中的所有数据库和所有表拥有权限。
  * 如果用户被授予database上的权限，那么他将对database中的所有表拥有权限。
  * 如果用户从catalog中撤销了权限，他也将失去对catalog中所有数据库和所有表的权限。
  * 如果用户从database中撤销了权限，他也将失去对database中所有表的权限。

### Privilege

* 一个Privilege可以定义一个object的级别，可以使用多个Privilege来控制对Object授予的访问粒度。Privilege是特定于Object的。不同的Object可能有不同的Privilege。如下：

| Privilege       | Description                                           | Can be Granted on        |
| --------------- | ----------------------------------------------------- | ------------------------ |
| SELECT          | 查询这个表的数据                                      | TABLE, DATABASE, CATALOG |
| INSERT          | 在表中插入更新或删除数据，在表中创建删除tag或者branch | TABLE, DATABASE, CATALOG |
| ALTER_TABLE     | 修改表的元数据包括表名、列名、表参数等                | TABLE, DATABASE, CATALOG |
| DROP_TABLE      | 删除表                                                | TABLE, DATABASE, CATALOG |
| CREATE_TABLE    | 在数据库中创建表                                      | DATABASE, CATALOG        |
| DROP_DATABASE   | 删除库                                                | DATABASE, CATALOG        |
| CREATE_DATABASE | 在catalog创建库                                       | CATALOG                  |
| ADMIN           | 创建或删除权限用户，授予或移除用户在catalog的特定权限 | CATALOG                  |

### User

* 可以授予权限的实体。用户通过密码进行身份验证。启用权限系统后，会自动创建两个权限用户。
  * **root用户**，在启用权限系统时由提供的root密码标识。此用户始终拥有catalog中的所有特权。
  * **anonymous用户**，如果在创建catalog时没有提供用户名和密码，则此用户为anonymous用户。

## Enable Privileges

* Paimon目前只支持基于文件的权限系统。只有 `'metastore' = 'filesystem'` (默认值)或`'metastore' = 'hive'`的catalog才支持权限系统。开启filesystem/hive catalog权限系统：

```sql
-- 使用想要开启权限系统的catalog
USE CATALOG `paimon_catalog_root`;
    
-- 初始化root账号密码
CALL sys.init_file_based_privilege('root-password');
```

* 启用权限系统后，需要重新创建catalog并以`root身份进行身份验证`，以创建其他用户并授予他们权限。

> 权限系统不会影响现有的catalog。这些catalog仍然可以自由访问和修改表。如果您想在这些catalog中使用权限系统，请删除并重新创建所有catalog。

## Accessing Privileged Catalogs

* 要访问权限catalog并以用户身份进行身份验证，需要在创建catalog时定义`user`和`password` catalog选项，如下：

```sql
CREATE CATALOG paimon_catalog_root WITH (
   'type'='paimon',
   'warehouse'='file:/Users/huangshimin/Documents/study/flink/paimonData',
   'user' = 'root',
   'password' = 'root'
 );
```

## Creating Users

* 必须以具有`ADMIN`权限(例如root)的用户身份进行身份验证才能执行此操作。

```sql
-- 切换到具有ADMIN权限的catalog
USE CATALOG `paimon_catalog_root`;
-- 创建新用户并设置账号密码
CALL sys.create_privileged_user('hsm', 'hsm');
```

## Dropping Users

* 必须以具有`ADMIN`权限(例如root)的用户身份进行身份验证才能执行此操作。

```sql
-- 切换到具有ADMIN权限的catalog
USE CATALOG `paimon_catalog_root`;
-- 删除用户hsm
CALL sys.drop_privileged_user('hsm');
```

## Granting Privileges to Users

* 必须以具有`ADMIN`权限(例如root)的用户身份进行身份验证才能执行此操作。

```sql
-- 切换到具有ADMIN权限的catalog
USE CATALOG `paimon_catalog_root`;
-- 授予用户hsm查询权限
CALL sys.grant_privilege_to_user('hsm', 'SELECT');
-- 授予用户hsm查询my_db数据库下各个表权限
CALL sys.grant_privilege_to_user('hsm', 'SELECT', 'my_db');
-- 授予用户hsm查询my_db库的my_tbl表权限
CALL sys.grant_privilege_to_user('hsm', 'SELECT', 'my_db', 'my_tbl');
```

## Revoking Privileges to Users

* 必须以具有`ADMIN`权限(例如root)的用户身份进行身份验证才能执行此操作。

```sql
-- 切换到具有ADMIN权限的catalog
USE CATALOG `paimon_catalog_root`;

CALL sys.revoke_privilege_from_user('user', 'SELECT');

CALL sys.revoke_privilege_from_user('user', 'SELECT', 'my_db');

CALL sys.revoke_privilege_from_user('user', 'SELECT', 'my_db', 'my_tbl');
```

