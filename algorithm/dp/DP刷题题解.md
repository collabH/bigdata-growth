# 斐波那契数列

```text
定位状态转移方程:F(n)=F(n-2)+F(n-1)
base case: f(1)=1,f(0)=0,f(2)=1
```

* 暴力法
```java
class Solution {
    public int fib(int n) {
         if(n==1||n==2){
            return 1;
        }
        return fib(n-1)+fib(n-2);
    }
}
```
* DP Table法
```java

```
* 压缩状态法
```java
class Solution {
    public int fib(int n) {
         if(n==1||n==2){
            return 1;
        }
        int current=0;
        int prev=1,two=1;
        for(int i=3;i<=n;i++){
            current=first+two;
            two=first;
            first=current;
        }
        return current;
    }
}
```