# Scala基础

## 入门

### 基本类型

* Byte
* Char
* Short
* Int
* Long
* BigInt
* Float
* Double
* Boolean
* Unit

### val和var的区别

```properties
  不管是val还是var，都可以用来定义变量。用val定义的变量是不可变得，初始化之后值就固定类似于java的final关键字修饰的变量，用var定义的变量是可变的，可以修改多次。
  不可变只作用于变量本身，而不作用于变量所引用的实例，比如val buffer=new StringBuffer(),这里不可以将buffer重新指向其他stringBuffer但是可以使用buffer的append方法。
```

### RichInt方法

```scala
1 to 5 ==>Range(1,2,3,4,5)
1 until 5==>Range(1,2,3,4)
// start起始值，end结束值，step步数，类似于滑动窗口
Range(start,end,step)
```

### 元组和多重赋值

* 元组是不可变的。

```scala
  def getName = {
    // 元祖
    ("hsm", "hello", "laoge")
  }

  def use = {
    // 多重赋值
    val (name, say, flag) = getName
    print(name,say,flag)
  }
```

### Scala和java的区别

#### "=="

* scala重的"=="不管什么类型都是针对值的比较，eq()比较引用
* java"=="比较引用地址，equals比较直但是对于一些没有重写Object的equals方法的对象，底层使用的是"=="，需要重写equals方法。

#### 访问修饰符

* 如果不指定任何访问修饰符，java是默认为包内可见，scala默认为public
* java的protected对任何包的派生类加上当前包的任何类，都可以访问，scala只有派生类可以访问。
* scala可以定义访问修饰符作用的范围。

### Scala的构造类

```scala
//主构造器
class ConstructorPerson(val name: String, val age: Int) {
  println(name, age)

  var sex: String = _

  //附属构造器
  def this(name: String, age: Int, sex: String) {
    //附属构造器的第一行代码必须调用只构造器或者其他附属构造器
    this(name, age)
    this.sex = sex
  }

  override def toString: String = this.name + ":" + this.age + ":" + this.sex
}
```

* 需要类似Java的getter和setter方法可以在属性加上注解`@BeanProperty`

### 类继承

* scala中继承一个基类，重写的方法需要override关键字，只有主构造函数才能往基类构造函数中传参数。

```scala
class Animal(val name: String, val gender: String) {

  println("animal:", this.name, this.gender)

  def eat = {
    println("吃")
  }
}

 class Dog(override val name: String, override val gender: String, eat: String) extends  Animal(name, gender) {
  println("dog:", this.name, this.gender, this.eat)
  override def toString: String = "Dog is overrider"
}
```

### 单例对象

```scala
“class Marker(val color: String) {
  println("Creating " + this)

  override def toString() : String = "marker color " + color
}

object MarkerFactory {
  private val markers = Map(
    "red" -> new Marker("red"),
    "blue" -> new Marker("blue"),
    "green" -> new Marker("green")
  )

  def getMarker(color: String) =
    if (markers.contains(color)) markers(color) else null
}

println(MarkerFactory getMarker "blue")
println(MarkerFactory getMarker "blue")
println(MarkerFactory getMarker "red")
println(MarkerFactory getMarker "red")
println(MarkerFactory getMarker "yellow")
```

### 伴生对象

* class对象虽然指定为private但是它的伴生对象仍然可以访问。

```scala
class Ban private {
  print("xxx", this)

  override def toString: String = "hhh"
}

object Ban {

  def main(args: Array[String]): Unit = {
    println(new Ban)
  }
}
```

## 自适应类型

* scala提供三个特殊的类，Nothing(所有类的子类)、Option、Any(相当于java的Object对象)

### 容器和类型推导

```scala
import java.util._

var list1 = new ArrayList[Int]
// 这里实际上是ArrayList[Nothing]
var list2 = new ArrayList

list2 = list1 // Compilation Error”
```

### Any类型

* Any类型下包含AnyRef和AnyVal，最下层是Nothing，它是所有类的子类，Any是一个抽象类。
* AnyRef会直接映射为Object，AnyVal和Any会类似于反型擦除的操作映射给Object

### Option类型

```scala
def commentOnPractice(input: String) = {
    //rather than returning null
    if (input == "test") Some("good") else None
  }
  for (input <- Set("test", "hack")) {
    val comment = commentOnPractice(input)
    println("input " + input + " comment " +
      comment.getOrElse("Found no comments"))
  }
```

### 传递变参

```scala
// 定义可变参数
def max(values: Int*) = values.foldLeft(values(0)) { Math.max }

//传递可变参数
max(1,2,3,4)

// 将数组转换为可变参数
var arr=Array(1,23,4)
max(arr:_*)
```

### 协变和逆变

* 将子类实例的容器赋给基类容器的能力称为协变（covariance）。将超类实例的容器赋给子类容器的能力称为逆变（contravariance）。默认情况下，Scala对二者都不支持。
* 可以使用Parent<:Son,来完成协变

```scala
class MyList[+T] //...

var list1 = new MyList[int]
var list2 : MyList[Any] = null

list2 = list1 // OK 
```

## 函数值和闭包

### curry化

* curry化可以把函数从接收多个函数转换成接收多个参数列表。

```scala
object CurryFunction extends App {

  def sum(a: Int, b: Int) = a + b

  println(sum(2, 3))

  //curry函数 spark sql dataflow中使用，将原来接受俩个参数的函数转换为2
  def sum2(a: Int)(b: Int) = a + b

  println(sum2(2)(3))
}
```

### 参数的位置标记法

* 如果某个参数在函数中仅使用一次可以使用`_`表示。

### Execute Around Method模式

```scala
class Resource private() {
  println("Starting transaction...")

  private def cleanUp() { println("Ending transaction...")}

  def op1 = println("Operation 1")
  def op2 = println("Operation 2")
  def op3 = println("Operation 3")
}

object Resource {
  def use(codeBlock: Resource => Unit) {
    val resource = new Resource

    try {
      codeBlock(resource)
    }
    finally {
      resource.cleanUp()
    }
  }

  def main(args: Array[String]): Unit = {
    use(data=>print(data))
  }
}
```

### 偏函数

* 调用函数可以说成是将函数应用于实参。如果传入所有的预期的参数，就完全应用了这个函数。如果只传入几个参数，就会得到一个偏应用函数。这给了你一个便利，可以绑定几个实参，其他的留在后面填写。

```scala
class PartialFunction {

  def log(date: Date, message: String) = {
    println(date, message)
  }
}

object App {
  def main(args: Array[String]): Unit = {
    val function = new PartialFunction
    // 偏函数
    val partialFunction: String => Unit = function.log(new Date(), _: String)
    partialFunction("大")
    partialFunction("小")
  }
}
```

## Trait和类型转换

### 选择性实现

```scala
val cat = new Cat("cat") with Friend
cat listen
```

### 隐式类型转换

* 将类型通过其他类转换成其他类型的方式就是隐式子转换

```scala
class ImplicitDemo(number: Int) {
  def days(when: String): Date = {
    var date = Calendar.getInstance()
    when match {
      case ImplicitDemo.ago => date.add(Calendar.DAY_OF_MONTH, -number)
      case ImplicitDemo.from_now => date.add(Calendar.DAY_OF_MONTH, number)
      case _ => date
    }
    date.getTime()
  }
}

object ImplicitDemo {
  val ago = "ago"
  val from_now = "from_now"

  implicit def convertInt2DateHelper(number: Int) = new ImplicitDemo(number)

  def main(args: Array[String]): Unit = {
    2 days ago
  }
}
```

## Scala容器

### Set

* scala提供可变容器和不变容器，在多线程中可以使用不变容器，这样也可以保证线程安全。

 ```scala
object SetApp extends App {

  //不可变，声明后的集合就无法改变了
  val set: Set[Int] = Set(1, 2, 3, 4, 5)
  println(set.+(10))
  println(set)

  set filter {
    case data =>
      data > 4
  } foreach (println)

  //可变Set集合
  private val set1: mutable.Set[Int] = scala.collection.mutable.Set(12, 3, 4, 5, 6)
  // 添加元素
  set1 += 1
  set1 += 2
  set1.head

  // 合并俩个set
  private val mergeSet: Set[Int] = set ++ set1

  println(mergeSet)

  // map操作
  mergeSet.map((data: Int) => data * 2)
    .foreach(println)

  // &  计算交集 
  println(set & set1)

  // &~ 计算差集
  println(set &~ set1)

}
 ```

### Map

* 存在可变和不可变Map

```scala
object MapApp extends App {
  // create
  val map = Map("hsm" -> 24, "wy" -> 24)
  println(map)

  // filter
  map filter { case (name: String, age: Int) =>
    println(s"$name --- $age")
    "hsm".equals(name) && 24 == age
  } foreach (println)

  // get
  println(map("hsm"))
  println(map.get("wy"))
  println(map get "wy")

  // put 不可变
  println(map.+("zzl" -> 24))
  println(map.+(("ls", 11)))
  println(map.+("hsm1"))

  // update 向不变容器添加元素
  private val stringToInt: Map[String, Int] = map.updated("wy1", 24)
  
  println(map)
}
```

### List

* 只有不可变list，可变list可以使用Java或者ListBuffer

```scala
  //Nil相当于空的集合
  val list = List(1, 2, 3, 4, 5)

  //list是由head和tail构成
  println(list.head) //1
  println(list.tail) //2,3,4,5
  println(list(1)) //2

  //head::tail 在List前添加a

  val list1: List[Int] = 1 :: Nil
  val list2 = 2 :: list1
  println(3 :: list2)

  // ::: 在List前添加list
  println(list2.:::(List(4)))

  // filter exists
  println(list2.filter(data => data > 1))
  println(list2.exists(data => data == 2 && data == 3))
  // drop
  println(list2.drop(1))

  // foldLeft  类似foreach,可以给一个zeroValue 从左边开始计算
  println(list2.foldLeft(1)((total, data) => {
    total + data
  }))
```

### for表达式

```scala
// 1 2 3
  for (i <- 1 to 3) {
    println(i)
  }
  // 1 2
  for (elem <- 1 until 3) {
    println(elem)
  }
  // for filter
  for (elem <- 1 to 10; if elem % 2 == 0) {
    println(elem)
  }
  
  for {
    i <- 1 to 3
    if i > 2
  } {
    println(i)
  }
```

## 模式匹配

```scala
object CaseDemo extends App {
  // 字符串匹配
  def stringCase(word: String) = {
    word match {
      case "a" =>
        println(word)
    }
  }

  stringCase("a")

  // 匹配通配符
  def enumCase(word: String) = {
    DayOfWeek.withName(word) match {
      case SUNDAY => {
        println(SUNDAY.toString)
      }
    }
  }

  enumCase("Sunday")

  // 匹配元组
  def tupleCase(input: Any) = {
    input match {
      case (a, b) => println(a, b)
      case "done" => println("done...")
      case _ => None
    }
  }

  // 匹配list
  def listCase(list: List[String]) = {
    list match {
      case List("a") => println(list)
      case ::(head, tail) => println(head, tail)
    }
  }

  listCase(List("a"))
  listCase(List("a", "c"))

  tupleCase((1, 2))
  tupleCase("done")
  println(tupleCase(1))

  // case表达式的模式
  class Sample {
    val max = 100
    val MIN = 0

    def process(input: Int) {
      input match {
        case this.max => println("You matched max")
        case MIN => println("You matched min")
        case _ => println("Unmatched")
      }
    }
  }

  new Sample().process(100)
  new Sample().process(0)
  new Sample().process(10)

  // 使用case类模式匹配
  def caseClassCase(trade: Trade) = {
    trade match {
      case Buy() => println("buy")
      case Sell() => println("sell")
      case _ => println("nothing")
    }
  }

  caseClassCase(Buy())
  caseClassCase(Sell())
}

object DayOfWeek extends Enumeration {
  val SUNDAY = Value("Sunday")
  val MONDAY = Value("Monday")
  val TUESDAY = Value("Tuesday")
  val WEDNESDAY = Value("Wednesday")
  val THURSDAY = Value("Thursday")
  val FRIDAY = Value("Friday")
  val SATURDAY = Value("Saturday")
}

// 使用case类进行模式匹配
abstract class Trade()

case class Sell() extends Trade

case class Buy() extends Trade
```

