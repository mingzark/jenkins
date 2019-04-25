#!/bin/bash
DATE=`date +%Y-%m-%d_%H-%M-%S`
METHR=$1
GROUP_LIST=$2


function IP_List(){
  if [[ ${GROUP_LIST} == "group1" ]];then
  Server_IP="172.20.102.13"

  elif [[ ${GROUP_LIST} == "group2" ]];then
  Server_IP="172.20.102.46"
  ssh root@172.18.13.101  "echo "enable  server webservers/172.20.102.13" | socat stdio /run/haproxy/admin.sock"
  echo "172.20.102.13 从172.18.13.101添加成功"
  ssh root@172.18.13.102  "echo "enable  server webservers/172.20.102.13" | socat stdio /run/haproxy/admin.sock"
  echo "172.20.102.13 从172.18.13.102添加成功"

  elif [[ ${GROUP_LIST} == "groupall" ]];then
  Server_IP="172.20.102.13 172.20.102.46"
  fi
}

function Code_Clone(){
  cd  /data/git  && rm -rf bbs
  git clone git@172.20.102.18:bbs/bbs.git
}

function make_zip(){
  cd /data/git/bbs && tar czvf testapp.tar.gz  ./*
  echo "压缩包打包完毕!"
  }

function down_node(){
  for node in ${Server_IP};do
    ssh root@172.18.13.101  ""echo disable  server webservers/${node}" | socat stdio /run/haproxy/admin.sock"
    echo "${node} 从172.18.13.101摘除成功"
    ssh root@172.18.13.102  ""echo disable  server webservers/${node}" | socat stdio /run/haproxy/admin.sock"
    echo "${node} 从172.18.13.102摘除成功"
  done
}

function stop_tomcat(){
  for node in ${Server_IP};do
    ssh -p22 www@${node} "daemon.sh stop"
  done
}

function start_tomcat(){
  for node in ${Server_IP};do
    ssh -p22  www@${node} "daemon.sh start"
  done
}
    
function scp_codefile(){
  cd /data/git/bbs
  Dir_Name=/data/tomcat/tomcat_webdir/testapp-${DATE}
  Web_Dir=/data/webapp/ROOT
  App_Name=/data/tomcat/tomcat_appdir/testapp-${DATE}.tar.gz
  for node in ${Server_IP};do
    scp -P 22 testapp.tar.gz www@${node}:${App_Name}
    ssh -p 22 www@${node} "mkdir ${Dir_Name} && tar xvf ${App_Name} -C ${Dir_Name} && rm -rf ${Web_Dir} && ln -sv ${Dir_Name} ${Web_Dir} "
  done
}

function web_test(){
  for node in ${Server_IP};do
    NUM=`curl -s -I -m 10 -o /dev/null  -w %{http_code}  http://${node}:8080/test.html`
    if [[ ${NUM} -eq 200 ]];then
       echo "${node} 测试通过,即将添加到负载"
       add_node ${node}
    else
       echo "${node} 测试失败,请检查该服务器是否成功启动tomcat"
    fi
  done
}


function add_node(){
   node=$1
    echo ${node},"----->"
    if [ ${GROUP_LIST} == "group1" ];then
       echo "172.20.102.13部署完毕,请进行代码测试!"
    else
    ssh root@172.18.13.101  ""echo enable  server webservers/${node}" | socat stdio /run/haproxy/admin.sock"
    echo "${node} 从172.18.13.101 添加成功"
    ssh root@172.18.13.102  ""echo enable  server webservers/${node}" | socat stdio /run/haproxy/admin.sock"
    echo "${node} 从172.18.13.102 添加成功"
    fi
}



function rollback_last_version(){
  for node in ${Server_IP};do
    NOW_VERSION=`ssh -p 22 www@${node} ""/bin/ls -l  -rt /data/webapp/ | awk -F"->" '{print $2}' | tail -n1 |xargs basename""`
    echo $NOW_VERSION
    Last_Version=`ssh -p 22  www@${node}  ""/bin/ls -l  -rt -d  /data/tomcat/tomcat_webdir/testapp* | grep -B 1 ${NOW_VERSION} | head -n1 | awk '{print $9}'""`
    ssh -p 22 www@${node} "rm -rf /data/webapp/ROOT && ln -sv ${Last_Version} /data/webapp/ROOT"
  done 
}
function git_rollback_last_version(){
  cd  /data/git/bbs
  git reset --hard HEAD^
}
function delete_history_version(){
  for node in ${Server_IP};do
    Web_Num=`ssh -p 22  www@${node}  ""/bin/ls -l  -rt -d  /data/tomcat/tomcat_webdir/testapp* | wc -l""`
    App_Num=`ssh -p 22  www@${node}  ""/bin/ls -l  -rt -d  /data/tomcat/tomcat_appdir/testapp* | wc -l""`
    if [ ${Web_Num} -gt 5 ];then
    Web_Delete_Name=`ssh -p 22  www@${node} ""/bin/ls -l -rt -d  /data/tomcat/tomcat_webdir/testapp* | head -n1 | awk '{print $9}'""`
    ssh -p 22  www@${node} "rm -rf ${Web_Delete_Name}"
    echo "${node} 成功删除${Web_Delete_Name}"
    fi
    if [ ${App_Num} -gt 5 ];then
    App_Delete_Name=`ssh -p 22  www@${node} ""/bin/ls -l -rt -d  /data/tomcat/tomcat_appdir/testapp* | head -n1 | awk '{print $9}'""`
    ssh -p 22  www@${node} "rm -rf ${App_Delete_Name}"
    echo "${node} 成功删除${App_Delete_Name}"
    fi
  done
}
main(){
   case ${METHR}  in
      deploy)
        IP_List;        
        Code_Clone;
        make_zip;
        down_node;
        stop_tomcat;
        scp_codefile;
        start_tomcat;
        web_test;
        delete_history_version;
         ;;
      rollback_last_version)
        IP_List;
        down_node;
        stop_tomcat;
        rollback_last_version;
        start_tomcat;
        web_test;
         ;;
      git_rollback_last_version)
        IP_List;
        git_rollback_last_version;
        make_zip;
        down_node;
        stop_tomcat;
        scp_codefile;
        start_tomcat;
        web_test;
        delete_history_version;
         ;;
    esac
}

main $1 $2 $3
