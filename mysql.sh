#!/bin/bash
yumconfig(){
rm -rf /etc/yum.repos.d/*
echo "[development]
name=rhel7
baseurl=ftp://192.168.4.254/rhel7
enabled=1
gpgcheck=0
" > /etc/yum.repos.d/rhel7.repo
yum repolist | tail -1
}

installmysql(){

i=$(rpm -qa | grep mariadb)

if [ -z $i ];then
   echo "no install Mariadb !"
else
    rpm -e --nodeps $i
fi
   
tar -xf mysql-5.7.17.tar
yum -y install perl-JSON
rpm -Uvh mysql-community-*.rpm


systemctl start mysqld && systemctl enable mysqld 

sed -i '/^\[mysqld\]/avalidate_password_policy=0' /etc/my.cnf

sed -i '/^\[mysqld\]/avalidate_password_length=6' /etc/my.cnf

systemctl restart mysqld

a=$(grep password /var/log/mysqld.log | awk 'NR==1{print $NF}')

mysqladmin -u root -p"$a" password "123456"
}

master1(){
        read -p "please input a log-bin name:" n
        echo "log-bin=$n
server-id=$[RANDOM%255]
binlog-format='mixed'
log-slave-updates
" >> /etc/my.cnf
        systemctl restart mysqld
        mysql -uroot -p -e "grant replication client,replication slave on *.* to syn@'%' identified by '123456';"

}

slave(){
       echo "server-id=$[RANDOM%254]" >> /etc/my.cnf
       systemctl restart mysqld
       read -p "please input master ip address:" b
       a=$(mysql -h$b -usyn -p123456 -e "show master status;" | awk 'NR==2{print $1}')
       c=$(mysql -h$b -usyn -p123456 -e "show master status;" | awk 'NR==2{print $2}')
       mysql -uroot -p -e "
       change master to
       master_host=\"$b\",
       master_user=\"syn\",
       master_password=\"123456\",
       master_log_file=\"$a\",
       master_log_pos=$c;"
       mysql -uroot -p -e "start slave;show slave status\G;"
      }
synmaster(){
       sed -i '/^\[mysqld\]/arpl_semi_sync_slave_enabled=1' /etc/my.cnf
       sed -i '/^\[mysqld\]/arpl_semi_sync_master_enabled=1' /etc/my.cnf
       sed -i '/^\[mysqld\]/aplugin-load = "rpl_semi_sync_master=semisync_master.so;rpl_semi_sync_slave=semisync_slave.so"' /etc/my.cnf
       systemctl restart mysqld

           }

synslave(){

        sed -i '/^\[mysqld\]/arpl_semi_sync_slave_enabled=1' /etc/my.cnf
        sed -i '/^\[mysqld\]/aplugin-load=rpl_semi_sync_slave=semisync_slave.so' /etc/my.cnf
        systemctl restart mysqld

          }



read -p "请输入你要进行的操作
按1配置yum，安装mysql
按2配置mysql主服务器
按3配置mysql从服务器
按4配置半复制mysql主服务器
按5配置半复制mysql从服务器
请输入序号(1-5):" num1
case "$num1" in
           1)
           yumconfig
           installmysql;;
           2)
           master1;;
           3)
           slave;;
           4)
           master1
           synmaster
           mysql -u root -p -e "show  variables  like 'rpl_semi_sync_%_enabled';"
           mysql -u root -p -e "show master status;";;
           5)
           slave
           synslave
           mysql -u root -p -e "show  variables  like 'rpl_semi_sync_%_enabled';";;
           *)
           exit;;
esac
