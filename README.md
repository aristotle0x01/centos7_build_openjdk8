## 1.原作者readme

###centos7_build_openjdk8###
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

但是gdb调试在打断点时比如**xxx.cpp:method**时，会提示：**No source file named xxx.cpp**。有几篇文章探讨这个问题，但是没有很好的解决方案[^1] [^2] [^3]。可以改用**lldb**调试，正常断点。

<br/>

### 2.3 vscode远程debug

**容器：**

* `docker run --name=jdk002 --security-opt seccomp=unconfined -p 1234:1234 -v  /path to/jdk8u:/var/shared/jdk8u  -idt bolingcavalryopenjdk:0.0.2_ok`
* `yum install gdb-gdbserver`
* `gdbserver  :1234 /var/shared/jdk8u/build/linux-x86_64-normal-server-slowdebug/jdk/bin/java -version`

**本地：**

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
              "engineLogging": true,
              "cwd": "${workspaceRoot}",
              "valuesFormatting": "parseText",
          }
      ]
  }
  ```

* vscode与容器源代码映射：本地建立软连接，这样本地和容器都有了**/var/shared/jdk8u**路径，即可启动本地单步调试

  `ln -s /path to/jdk8u /var/shared`。当然这是一种取巧的方式，也可以通过**sourceFileMap**解决。

* 本地vscode:  `Run / Start Debugging`

<br/>

## 3.ref

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

