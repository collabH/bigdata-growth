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

