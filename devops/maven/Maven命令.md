# Maven命令

## 上传jar包到私服
```jshelllanguage
mvn -s $MAVEN_HOME/conf/xx-settings.xml deploy:deploy-file -DgroupId=org.pentaho -DartifactId=pentaho-aggdesigner-algorithm -Dversion=5.1.5-jhyde -Dpackaging=jar -Dfile=/Users/xiamuguizhi/Downloads/pentaho-aggdesigner-algorithm-5.1.5-jhyde.jar -Durl=https://nexus.xxx.cn/repository/maven-releases/ -DrepositoryId=releases
```

## 使用多核编译

* -TnC:使用多核加速编译