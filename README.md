## 1.原作者readme

**centos7_build_openjdk8**
Build and compile openjdk8 src at centos7

1. <code>docker build -t bolingcavalryopenjdk:0.0.1 .</code>
2. <code>docker run --name=jdk001 -idt bolingcavalryopenjdk:0.0.1</code> 
3. <code>docker exec -it jdk001 /bin/bash</code>
4. <code>cd /usr/local/openjdk</code>
5. <code>./start_make.sh</code>
6. Waiting for the building complete, then goto build/, you will find linux-xxxxx path, new jdk is in here.
7. If you have question, try send email to : zq2599@gmail.com

<br/>

## 2.改造

* 使用**volume**映射源代码
  * 不必加载源文件，可灵活选择版本
  * 本地变更后易于容器内再次编译

* 使用vscode可视化debug

  <br/>

### 2.1 编译改造

* **Dockerfile**变更见源文件
* <code>docker build -t bolingcavalryopenjdk:0.0.2 .</code>
* `docker run --name=jdk002 --security-opt seccomp=unconfined -v  /path to/openjdk:/var/shared/jdk8u  -idt bolingcavalryopenjdk:0.0.2`
  * `docker exec -it jdk002 /bin/bash`
  * `cd /var/shared/jdk8u`
  * `chmod a+x configure && ./configure --with-debug-level=slowdebug --with-native-debug-symbols=internal --enable-debug-symbols`
  * `make all ZIP_DEBUGINFO_FILES=0 ENABLE_FULL_DEBUG_SYMBOLS=1 DISABLE_HOTSPOT_OS_VERSION_CHECK=OK CONF=linux-x86_64-normal-server-slowdebug`
  * 提示缺少的可以通过**yum install xx**安装即可
  * 验证：`cd build/linux-x86_64-normal-server-release/jdk/bin && ./java -version`
* `docker commit 47b978003035 bolingcavalryopenjdk:0.0.2_ok` (可将上述编译后容器commit)，停止并删除该容器
* `docker run --name=jdk002 --security-opt seccomp=unconfined -p 1234:1234 -v  /path to/jdk8u:/var/shared/jdk8u  -idt bolingcavalryopenjdk:0.0.2_ok`

<br/>

### 2.2 本地debug

 `gdb --args ./java -version`

但是gdb调试在打断点时比如**xxx.cpp:method**时，会提示：**No source file named xxx.cpp**。有几篇文章探讨这个问题，但是没有很好的解决方案[^1] [^2] [^3]。解决方法有二：

* 可以改用**lldb**调试，绕过去

* 从openjdk-8u分支切换到8b分支则无此问题(Make breakpoint pending on future即可)

* 进入gdb之后，执行：`directory /var/shared/jdk8u`明确告诉gdb源码路径。之后再打断点`break classFileParser.cpp:3735`，会出现类似：

  > No source file named classFileParser.cpp.
  > Make breakpoint pending on future shared library load? (y or [n])
  >
  > 选择: Y 
  >
  > **Breakpoint 1 (classFileParser.cpp:3735) pending.** // 表示未来会在此处断点

<br/>

### 2.3 vscode远程debug

**容器：**

* `docker run --name=jdk002 --security-opt seccomp=unconfined -p 1234:1234 -v  /path to/jdk8u:/var/shared/jdk8u  -idt bolingcavalryopenjdk:0.0.2_ok`

* `yum install gdb-gdbserver`

* `gdbserver  :1234 /var/shared/jdk8u/build/linux-x86_64-normal-server-slowdebug/jdk/bin/java -version`

  注意**java**完整路径，影响断点同步

**本地：**

* 安装gdb

* vscode安装插件:  **Native Debug** (WebFreak)

  配置文件**launch.json**如下：

  ```
  {
      "version": "0.2.0",
      "configurations": [
          {
              "type": "gdb",
              "request": "attach",
              "name": "Attach to gdbserver",
              "executable": "/var/shared/jdk8u/build/linux-x86_64-normal-server-slowdebug/jdk/bin/java",
              "target": "localhost:1234",
              "remote": true,
              "printCalls": true,
              "cwd": "${workspaceRoot}",
              "valuesFormatting": "parseText",
          }
      ]
  }
  ```
  
* vscode与容器源代码映射：本地建立软连接，这样本地和容器都有了`/var/shared/jdk8u`路径，即可启动本地单步调试

  `ln -s /path to/jdk8u /var/shared`。当然这是一种取巧的方式，也可以通过**sourceFileMap**解决

* 本地vscode:  `Run / Start Debugging`

* 打断点无效问题，无论在什么路径测试java程序，注意**gdbserver**使用编译后完整路径`/var/shared/jdk8u/build/linux-x86_64-normal-server-slowdebug/jdk/bin/java`，仅仅`./java`不行

<br/>

### 2.4 hsdis编译

```shell
cd hotspot/src/share/tools/hsdis
wget http://ftp.heanet.ie/mirrors/ftp.gnu.org/gnu/binutils/binutils-2.29.tar.gz
tar -xzf binutils-2.29.tar.gz
sed -ri 's/development=.*/development=false/' ./binutils-2.29/bfd/development.sh # set development to false
make BINUTILS=binutils-2.29 ARCH=amd64

// 成功后拷贝到相关目录
sudo cp build/linux-amd64/hsdis-amd64.so ...
./linux-x86_64-normal-server-slowdebug/jdk/lib/amd64/server/hsdis-amd64.so
./linux-x86_64-normal-server-slowdebug/jdk/lib/amd64/hsdis-amd64.so
./linux-x86_64-normal-server-slowdebug/hotspot/dist/jre/lib/amd64/server/hsdis-amd64.so
./linux-x86_64-normal-server-slowdebug/hotspot/dist/jre/lib/amd64/hsdis-amd64.so
```

如果遇到下面错误：
> hsdis.c:314:3: error: incompatible type for argument 1 of 'disassembler'

可参考[hsdis disassembler plugin does not compile with binutils 2.29+
](https://bugs.openjdk.org/browse/JDK-8191006) 按照**CUSTOMER SUBMITTED WORKAROUND :**部分修改hsdis.c代码即可

 [Build hsdis for JDK 1.8 on Ubuntu](http://neverfear.org/blog/view/162/Build_hsdis_for_JDK_1_8_on_Ubuntu)

[Developers disassemble! Use Java and hsdis to see it all](https://blogs.oracle.com/javamagazine/post/java-hotspot-hsdis-disassembler)

<br/>

## 3.reference

[**在docker上编译openjdk8**](https://blog.51cto.com/zq2599/5193163)

[**修改，编译，GDB调试openjdk8源码(docker环境下)**](https://blog.51cto.com/zq2599/5195647)

[Debugging C/C++ Programs Remotely Using Visual Studio Code and gdbserver](https://medium.com/@spe_/debugging-c-c-programs-remotely-using-visual-studio-code-and-gdbserver-559d3434fb78)

[How to Remote Debugging with Visual Studio Code](https://nnfw.readthedocs.io/en/stable/howto/how-to-remote-debugging-with-visual-studio-code.html)

[Configure C/C++ debugging](https://code.visualstudio.com/docs/cpp/launch-json-reference#_sourcefilemap)

[VS Code Remote Development](https://code.visualstudio.com/docs/remote/remote-overview)

[Pipe transport](https://code.visualstudio.com/docs/cpp/pipe-transport)

[Remote Development using SSH](https://code.visualstudio.com/docs/remote/ssh)

[MacOS 编译 openjdk8 并导入 Clion 调试](https://www.cnblogs.com/dwtfukgv/p/14727290.html)

[搭建 JVM(HotSpot) 源码调试环境（OpenJDK8） ](https://www.cnblogs.com/jhxxb/p/11094578.html)

**gdb breakpoint issue**:

[^1]: [Could not step in cpp file when debug Openjdk8 hotspot in mac](https://stackoverflow.com/questions/45678886/could-not-step-in-cpp-file-when-debug-openjdk8-hotspot-in-mac)
[^2]:  [[讨论] HotSpot gdb调试, No source file named ...](https://hllvm-group.iteye.com/group/topic/39731)
[^3]: [GDB: Debug native part of java application (C/C++ libraries and JDK)](https://medium.com/@pirogov.alexey/gdb-debug-native-part-of-java-application-c-c-libraries-and-jdk-6593af3b4f3f)

