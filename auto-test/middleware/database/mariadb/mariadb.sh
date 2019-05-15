#!/bin/bash

############################################################################
#用例名称：mariadb
#用例功能：
#	版本检查：10.3.7
#	数据库初始化：关闭防火墙，准备一份基础配置文件my.cnf,初始化数据库
#	创建用户：创建普通用户test,并赋予本地和远程控制权限
#       创建/销毁testdb
#	基本查询功能：使用select进行查询
#	压力测试：使用sysbench v0.5对mariadb进行压力测试
#作者：mwx547872
#完成时间：2019/5/13
##############################################################################

######初始化变量，新建一些文件######
set -x
. ../../../../utils/sh-test-lib
. ../../../../utils/sys_info.sh


####初始化环境包含（日志开启入库，判断当前是否为root用户，安装所需要的包）#######
function init_env()
{
   ### @开启日志入库导入 @ 判断是否为root用户 @安装需要使用的安装包，以及依赖包
    if [ `whoami` != 'root' ];then
         echo "You must be the superuser to run this script" >$2
         exit 1
    fi
    ###@安装mariadb
      ./mariadb_10.3.7_install.sh
    ###@关闭防火墙
    case $distro in
         centos)
            systemctl stop firewalld.service
            pkgs="expect git unzip gcc gcc-c++ automake make libtool mariadb-devel"
            install_deps "${pkgs}"
            ;;
         debian)
           apt-get install ufw -y
           ufw enable
           ;;
    esac

}

####mariadb的基本功能实现（版本检查，数据库初始化，创建用户，基本查询功能）#####

function basic_function()
{


       ###@版本检查
      cd /usr/local/mariadb-10.3.7
      num=`./bin/mysql -V |grep -c "10.3.7-MariaDB"`
      if [ $num -eq 0 ];then
         print_info 1 check-mariadb-version
      else
         print_info 0 check-mariadb-version
      fi
      ####@准备配置文件my.cnf
      pwd
      echo 1111111111111111111111
      mv ./etc/my.cnf ./etc/my.cnf_bak
      touch ./etc/my.cnf
      echo "[mysqld]" >> ./etc/my.cnf
      echo "basedir=/usr/local/mariadb-10.3.7" >> ./etc/my.cnf
      echo "datadir=/ssd/data" >> ./etc/my.cnf
      echo "socket=/usr/local/mariadb-10.3.7/mysql.sock" >> ./etc/my.cnf
      echo "pid_file=/usr/local/mariadb-10.3.7/var/run/mysqld/mysqld.pid" >> ./etc/my.cnf
      echo "log_error=/usr/local/mariadb-10.3.7/var/log/mysqld.log" >> ./etc/my.cnf
      echo "port=2000" >> ./etc/my.cnf
      echo "user=root" >> ./etc/my.cnf
      echo "server_id=1" >> ./etc/my.cnf
      ###@初始化mariadb
      ./scripts/mysql_install_db --defaults-file=/usr/local/mariadb-10.3.7/etc/my.cnf
      print_info $? init_mariadb
      ###@启动mysqld进程
      nohup ./bin/mysqld_safe --defaults-file=/usr/local/mariadb-10.3.7/etc/my.cnf --ledir=/usr/local/mariadb-10.3.7/bin &
      print_info $? start-mariadb
      ###@为root用户设置密码
    # ./bin/mysqladmin -S /usr/loacal/mariadb-10.3.7/mysql.sock -u root password 'root'
    #  print_info $? set-root-password
      ###@创建用户 @创建/销毁testdb
      EXPECT=$(which expect)
      $EXPECT << EOF
      set timeout 100
      spawn ./bin/mysql --socket=/usr/local/mariadb-10.3.7/mysql.sock -u root -proot -v
      expect "MariaDB"
      send "grant all privileges on *.* to test@\"\%\" identified by \"test\";\r"
      expect "OK"
      send "grant all privileges on *.* to test@\"localhost\" identified by \"test\";\r"
      expect "OK"
      send "create database testdb;\r"
      expect "OK"
      send "drop database testdb;\r"
      expect "OK"
      send "create database testdb;\r"
      expect "OK"
      send "exit\r"
      expect eof
EOF

cd -


}

####使用sysbench对mariadb进行压力测试######
function performance_test()
{
  ####@压力测试
  pwd
  mv sysbench-0.5.zip /usr/local
  cd /usr/local/
  echo 22222222222222222222222
  unzip sysbench-0.5.zip
  cd sysbench-0.5
  ./autogen.sh
  ./configure --prefix=/usr/local/sysbench-0.5 --with-mysql
  make
  make install
  cd /usr/local/sysbench-0.5
  ./sysbench/sysbench --test=/usr/local/sysbench-0.5/sysbench/tests/db/parallel_prepare.lua --oltp-tables-count=250 --oltp-table-size=25000 --mysql-host=192.168.50.129 --mysql-port=2000 --mysql-db=testdb --mysql-user=test --mysql-password=test --num-threads=50 --max-requests=50 run
  print_info $? sysbench-mariadb-prepare

  ./sysbench/sysbench --test=/usr/local/sysbench-0.5/sysbench/tests/db/oltp.lua --oltp-tables-count=250 --oltp-table-size=25000 --mysql-host=192.168.50.129 --mysql-port=2000 --mysql-db=testdb --mysql-user=test --mysql-password=test --oltp-read-only=on --oltp-point-selects=10 --oltp-simple-ranges=1 --oltp-sum-ranges=1 --oltp-order-ranges=1 --oltp-distinct-ranges=1 --oltp-range-size=10 --max-requests=0 --max-time=60 --report-interval=2 --forced-shutdown=1 --num-threads=100 run
 print_info $? sysbench-mariadb-run

}

#####清理环境############
function clean_env()
{

 ###@卸载安装包 @结束进程，清理临时文件 @导入测试结果入库结束
 pkgs="expect automake libtool mariadb-devel"
 remove_deps "${pkgs}"


}

#####调用所有函数############
function main()
{
   ######调用所有的函数
   init_env
   basic_function
   performance_test
   clean_env
}

main
