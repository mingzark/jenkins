#!/bin/bash
echo $*
if [ "$1" == "group1" ];then
ip_list="www@172.20.102.13"
elif [ "$1" == "group2" ];then
ip_list="www@172.20.102.46"
elif [ "$1" == "groupall" ];then
ip_list="www@172.20.102.13 www@172.20.102.46"
fi
echo $ip_list
#打包
cd /var/lib/jenkins/workspace/test && zip -r web.war ./*
#停止tomcat删除旧版
pssh -H "$ip_list" "daemon.sh stop && rm -rf /data/webapp/ROOT/*"
#源码分发
pscp.pssh -H "$ip_list" /var/lib/jenkins/workspace/test/web.war /data/webapp/ROOT/
#解压源码并启动tomcat
pssh -H "$ip_list" "cd /data/webapp/ROOT &&unzip web.war && daemon.sh start"
