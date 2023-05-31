# OverView

## Bookkeeper API类型

* **Ledger API:**一种低级API，能够直接与ledger交互
* **Ledger Advanced API:**Ledger API的高级扩展，为应用程序提供更大的灵活性。
* **DistributedLog API**:提供方便抽象的高级API

## 取舍

* `Ledger API`提供直接访问ledgers，从而可以按照需求个性化使用Bookkeeper
* 但是，在大多数用例中，如果您想要类似`log stream`的能力，它需要管理诸如跟踪ledger，管理滚动ledger和数据保留之类的内容。在这种情况下，建议使用`DistribateLog API`，从应用程序的角度来看，语义类似于连续的日志流。

# Ledger API

* Ledger API是Bookkeeper低级API可以直接访问Ledger。

## 安装

### Maven依赖

```xml
<!-- in your <properties> block -->
<bookkeeper.version>4.16.1</bookkeeper.version>

<!-- in your <dependencies> block -->
<dependency>
  <groupId>org.apache.bookkeeper</groupId>
  <artifactId>bookkeeper-server</artifactId>
  <version>${bookkeeper.version}</version>
</dependency>
```

* Bookkeeper使用了protobuf和guava，如果程序内涉及不同版本的protobuf和guava可以使用Bookkeeper的shade包

```xml
<!-- in your <properties> block -->
<bookkeeper.version>4.16.1</bookkeeper.version>

<!-- in your <dependencies> block -->
<dependency>
  <groupId>org.apache.bookkeeper</groupId>
  <artifactId>bookkeeper-server-shaded</artifactId>
  <version>${bookkeeper.version}</version>
</dependency>
```

## 创建Client

```java
try {
  String connectionString = "localhost:2181";
  BookKeeper bkClient = new BookKeeper(connectionString);
} catch (InterruptedException | IOException | BKException e) {
  e.printStackTrace();
}
```

## Ledger操作

### add

* 同步创建

```java
BookKeeper bookKeeper = confBkCls(metaServiceUrl);
            byte[] password = "test-ledger".getBytes(StandardCharsets.UTF_8);
            // 同步创建ledger
            LedgerHandle ledger = bookKeeper.createLedger(BookKeeper.DigestType.CRC32, password);
```

* 异步创建

```java
  byte[] password = "test-ledger".getBytes(StandardCharsets.UTF_8);
            // 异步创建ledger
            bookKeeper.asyncCreateLedger(3,
                    2,
                    BookKeeper.DigestType.MAC,
                    password,
                    new AsyncCallback.CreateCallback() {
                        @Override
                        public void createComplete(int rc, LedgerHandle lh, Object ctx) {
                            System.out.println("Ledger successfully created");
                        }
                    },
                    "some context");
```

### delete

* 同步删除

```java
  bookKeeper.deleteLedger(5);
```

* 异步删除

```java
class DeleteEntryCallback implements AsyncCallback.DeleteCallback {
    public void deleteComplete() {
        System.out.println("Delete completed");
    }
}
bkClient.asyncDeleteLedger(ledgerID, new DeleteEntryCallback(), null);
```

## Entry操作

### add

```java
long entryId = ledger.addEntry(1L, "bookkeeper-entry".getBytes(StandardCharsets.UTF_8));
```

### read

```java
Enumeration<LedgerEntry> ledgerEntryEnumeration = ledger.readEntries(1, 99);
            while (ledgerEntryEnumeration.hasMoreElements()) {
                System.out.println(Arrays.toString(ledgerEntryEnumeration.nextElement().getEntry()));
            }
```

# Advanced Ledger API

* Bookkeeper在`4.5.0`版本提出Advanced Ledger API，其实Ledger API的扩展。

```java
   ClientConfiguration conf = new ClientConfiguration();
        String metaServiceUrl = "zk+hierarchical://localhost:2181/ledgers";
        conf.setMetadataServiceUri(metaServiceUrl);
        BookKeeper bk = new BookKeeper(conf);
        // 创建Bookkeeper客户端
        byte[] password = "password".getBytes();
        // 指定ledgerId，如果存在则报错 Ledger existed
//        long ledgerId = 1L;
//        LedgerHandle ledgerAdv = bk.createLedgerAdv(ledgerId
//                , 3, 3, 3, BookKeeper.DigestType.CRC32, password,
//                Maps.newHashMap());
        long ledgerId = 1235L;
        bk.newDeleteLedgerOp().withLedgerId(ledgerId)
                .execute().get();
        WriteAdvHandle wah = bk.newCreateLedgerOp()
                .withDigestType(DigestType.MAC)
                .withPassword(password)
                .withEnsembleSize(3)
                .withAckQuorumSize(2)
                .withWriteQuorumSize(3)
                .makeAdv()
                .withLedgerId(ledgerId)
                .execute().get();
        int nums = 100;
        for (int i = 0; i < 100; i++) {
            wah.write(i, ("test" + i).getBytes());
        }
        wah.close();
        ReadHandle rh = bk.newOpenLedgerOp()
                .withDigestType(DigestType.MAC)
                .withLedgerId(ledgerId)
                .withPassword(password)
                .execute().get();
        LedgerEntries entries = rh.read(1L, nums - 1);
        for (LedgerEntry entry : entries) {
            System.out.println(entry.getLedgerId() + ":" + entry.getEntryId());
            System.out.println(new String(entry.getEntryBytes()));
        }
        rh.close();
        bk.close();
```

