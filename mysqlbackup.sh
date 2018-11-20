#!/bin/bash

##检查是否安装Percona XtraBackup
checkev(){
which innobackupex &> /dev/null&&echo
if [ $? -eq 0 ];then
   echo "Percona XtraBackup was installed." 
else
   yum -y intall wget 
   wget https://www.percona.com/downloads/XtraBackup/Percona-XtraBackup-2.4.12/binary/redhat/7/x86_64/Percona-XtraBackup-2.4.12-r170eb8c-el7-x86_64-bundle.tar
   tar -xf Percona-XtraBackup-2.4.12-r170eb8c-el7-x86_64-bundle.tar
   yum -y install yum -y localinstall percona-xtrabackup-*
fi 
}

user='test' 
password='abc.123'
time=`date`
##完整备份
full_back(){
full_dir='/home/mysql_backup/full_backup'
#if [ ! -d ${full_dir} ];then
#   mkdir -p ${full_dir}
#else 
#   echo " ${full_dir} exsits"
#fi

innobackupex --user ${user} --password ${password}  --no-timestamp ${full_dir}/full-`date +%Y%m%d%H%M%S` &>/dev/null
if [ $? -eq 0 ];then
   echo -e "\033[42;30;5m $time full_backup SUCCESS! \033[0m" 
   last1=$(cd ${full_dir};ls |tail -1)
   list=$(cd ${full_dir};ls |head -2)
   num=$(cd ${full_dir};ls | head -2 |wc -l)
   tar -cvf ${full_dir}/$last1.tar ${full_dir}/$last1
   if [ $num -eq 2 ];then
      for i in $list 
      do
        rm -rf ${full_dir}/$i
      done
   fi
else
   echo -e "\033[41;30;5m $time full_backup FAILS! \033[0m" 
fi
}


##增量备份
incre_back(){
full_dir='/home/mysql_backup/full_backup'
increment_dir='/home/mysql_backup/increment_backup'
if [ ! -d ${increment_dir} ];then
   mkdir -p ${increment_dir}
else
   echo " ${increment_dir} exsits" &>/dev/null
fi

last1=$(cd ${full_dir};ls |head -1)
last2=$(cd ${increment_dir};ls |tail -1)
nozore=$(du -s ${increment_dir} | awk '{print $1}')

if [ ${nozore} -eq 0 ];then
   innobackupex --user ${user} --password ${password} --no-timestamp --incremental ${increment_dir}/increment-`date +%Y%m%d%H%M%S` --incremental-basedir=${full_dir}/$last1 &>/dev/null
   if [ $? -eq 0 ];then
      echo -e "\033[42;30;5m $time first incre_backup SUCCESS ! \033[0m"
   else
      echo -e "\033[41;30;5m $time first incre_backup FAILS ! \033[0m" 
   fi
   
   #用完整备份做第一次增量备份
else 
   innobackupex --user ${user} --password ${password}  --no-timestamp --incremental ${increment_dir}/increment-`date +%Y%m%d%H%M%S` --incremental-basedir=${increment_dir}/$last2 &>/dev/null
   if [ $? -eq 0 ];then
      echo -e "\033[42;30;5m $time incre_backup SUCCESS ! \033[0m"
   else
      echo -e "\033[41;30;5m $time  incre_backup FAILS ! \033[0m" 
   fi

   #用上次增量备份做增量备份 
fi
}


##增量备份还原
restore(){
full_dir='/home/mysql_backup/full_backup'
increment_dir='/home/mysql_backup/increment_backup'
last1=$(cd ${full_dir};ls |tail -1)
list=$(cd ${increment_dir}; ls | tail -7)

systemctl stop mariadb;rm -rf /var/lib/mysql/*
innobackupex --user ${user} --password ${password}  --apply-log --redo-only ${full_dir}/$last1       #对最后一次完整备份目录作apply-log redo-only操作

for i in ${list}
do
    innobackupex --user ${user} --password ${password}  --apply-log --redo-only ${full_dir}/$last1 \
--incremental-dir="${increment_dir}/$i"  #对最近7天内的增量备份作apply-log redo-only操作
done
        
innobackupex --user ${user} --password ${password}  --copy-back ${full_dir}/$last1                   #原还 

chown -R mysql:mysql /var/lib/mysql
systemctl start mariadb
}

while :
do
  echo -e "\033[31m 请小心操作，谨防数据丢失!\033[0m"
  echo -e "\033[31m 1————完全备份数据! \033[0m"
  echo -e "\033[31m 2————增量备份数据库! \033[0m"
  echo -e "\033[31m 3————增量还原数据库! \033[0m"
  echo -e "\033[31m 4————按其他任意键退出! \033[0m"
  read -p "请输入你的选择:" chioces

  case $chioces in
  1)
  full_back;;
  2)
  incre_back;;
  3)
  restore;;
  *)
   exit 0;;
   esac
done






   




