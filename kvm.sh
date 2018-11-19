#!/bin/bash

##定义字体颜色
RED_COLOR='\E[1;31m'  #红
GREEN_COLOR='\E[1;32m' #绿
YELOW_COLOR='\E[1;33m' #黄
BLUE_COLOR='\E[1;34m'  #蓝
PINK='\E[1;35m'      #粉红
RES='\E[0m'


##检查expect是否安装

exp(){
exp=$(rpm -qa | grep expect )
if [ -n $exp ];then
   echo 'expect instelled !'
else 
    yum -y install expect 
fi
}


##创建虚拟机

NEW(){
read -p "请输入想要创建虚拟机的编号（1-99）：" num  
echo -n "请再确认编号：" 
clone-vm7   &> /dev/null
[ $num -gt 9 ] && a=$num || a=0$num
virsh start rh7_node$a  &> /dev/null
echo -n "创建完毕，系统启动中"  
for aa in {1..15};do
	echo -n '#' 
	sleep 1
done
echo 
}

##进入虚拟机配置IP，主机名
Virtual(){
exp
expect << ETF
spawn virsh console rh7_node$a 
expect "换码符" {send "\r"}
expect "login:" {send "root\r"}
expect "密码：" {send "123456\r"}
expect "#" {send "hostnamectl set-hostname host$a\r"}
expect "#" {send "nmcli connection modify eth0 ipv4.method manual ipv4.addresses 192.168.4.$num/24 connection.autoconnect yes\r"}
expect "#" {send "nmcli connection up eth0\r"}
expect "#" {send "exit\r"}
ETF
}

##部署YUM仓库
YUM(){
expect << EOF
spawn ssh root@192.168.4.$num
expect "yes" {send "yes\r"}
expect "pass" {send "123456\r"}
expect "#" {send "rm  -rf  /etc/yum.repos.d/*.repo\r"}
expect "#" {send "yum-config-manager  --add ftp://192.168.4.254/rhel7\r"}
expect "#" {send "sleep 2\r"}
expect "#" {send "echo gpgcheck=0 >>/etc/yum.repos.d/192.168.4.254_rhel7.repo\r"}
expect "#" {send "exit\r"}
expect "#" {send "sed -i '3a gpgcheck=0' /etc/yum.repos.d/192.168.4.254_rhel7.repo\r"}
EOF
}

##给虚拟机添加网卡配置ip
ADDNET(){
read -p "please input connection address:" addr
read -p "please input a ifname:" ifname
read -p "please input configure address:" add

expect << EOF
spawn  ssh $addr
expect "#" {send "nmcli connection add type ethernet con-name $ifname ifname $ifname\r"}
expect "#" {send "nmcli connection modify $ifname ipv4.method manual ipv4.addresses $add/24 connection.autoconnect yes\r"}
expect "#" {send "nmcli connection up $ifname\r"}
expect "#" {send "exit\r"}
EOF
}

gat(){
read -p "please input connection address:" addr
read -p "please input a ifname:" ifname
read -p "please input configure gateway:" gate 

expect << EOF
spawn  ssh $addr
expect "#" {send "nmcli connection modify $ifname ipv4.gateway $gate\r"}
expect "#" {send "nmcli connection up $ifname\r"}
expect "#" {send "exit\r"}
EOF
}
copyid(){
if [ ! -d /root/.ssh ];then
ssh-keygen -f /root/.ssh/id_rsa -N '' 
fi 
expect << EOF 
spawn ssh-copy-id 192.168.4.$num
expect "(yes/no)?" {send "yes\r"}
expect "password:" {send "123456\r"}
expect "#"          {send "exit\r"}
EOF
}

##查看虚拟机例表

var=$(virsh list --all | awk 'NR>=3{print $2}')

##创建快照
sscreat(){
read -p "pleas input a name:" n
for x in $var
do 
  virsh snapshot-create-as $x $n
done
}

##恢复快照
recovery(){
for host in $var
do
echo $host
virsh snapshot-list $host
echo -e "\033[43m####################################################################  \033[0m"
done
read -p "please input a Machine_name:" m
read -p "pleas input a snapshot_name:" x
virsh snapshot-revert ${m} $x
}

##删除快照
ssdel(){
for host in $var
do
virsh snapshot-list $host
done
read -p "please input a name:" y
for i in $var
do 
   virsh snapshot-delete $i "$y"
done
}

##删除虚拟机

virdel(){
for a in $var
do
  virsh undefine $a 
  rm -f //var/lib/libvirt/images/$a.img
done
}


while :
do
echo -e "\t\033[43m  Welcome to use KVM System v1.0！！   \033[0m"
echo -e "\t${RED_COLOR}input 1 Create virtual-machine!${RES}"
echo -e "\t${RED_COLOR}input 2 Create snapshot!${RES}"
echo -e "\t${RED_COLOR}input 3 KVM snapshot recovery!${RES}"
echo -e "\t${RED_COLOR}input 4 Delete a snapshot!${RES}"
echo -e "\t${RED_COLOR}input 5 Delete virtual-machine!${RES}"
echo -e "\t${RED_COLOR}input 6 Add a network for virtual-machine!${RES}"
echo -e "\t${RED_COLOR}input 7 Add a gateway for virtual-machine!${RES}"
read -p "please input a number(1-6):" b 

case $b in 

1)
   NEW
   Virtual &> /dev/null
   YUM &> /dev/null
   copyid;;
2)
  sscreat;;
3)
  recovery;;
4)
   ssdel;;
5)
  virdel;;
6)
  ADDNET;;
7)
 gat;;
*)
  exit;;
esac 
done
