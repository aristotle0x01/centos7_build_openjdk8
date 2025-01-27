# Docker image of compile and build enviroment for openjdk8
# VERSION 0.0.1
# Author: bolingcavalry

#基础镜像使用centos7
FROM daocloud.io/library/centos:centos7

#作者
MAINTAINER BolingCavalry <zq2599@gmail.com>

#定义工作目录
ENV WORK_PATH /usr/local

#定义jdk1.7的文件名
ENV JDK_RPM_FILE jdk-7u71-linux-x64.rpm

#定义openJdk源码的文件名
ENV OPENJDK_SRC_ZIP openjdk-8-src-b132-03_mar_2014.zip

#yum更新
RUN yum -y update

#安装工具集
RUN yum -y groupinstall "Development Tools"

#安装即将用到的软件
RUN yum -y install unzip libXtst-devel libXt-devel libXrender-devel cups-devel freetype-devel alsa-lib-devel which 

#把分割过的jdk1.7安装文件复制到工作目录
COPY ./jdkrpm-* $WORK_PATH/

#用本地分割过的文件恢复原有的jdk1.7的安装文件
RUN cat $WORK_PATH/jdkrpm-* > $WORK_PATH/$JDK_RPM_FILE

#本地安装jdk1.7
RUN yum -y localinstall $WORK_PATH/$JDK_RPM_FILE

#删除分割文件
RUN rm $WORK_PATH/jdkrpm-*

#删除jdk安装包文件
RUN rm $WORK_PATH/$JDK_RPM_FILE
