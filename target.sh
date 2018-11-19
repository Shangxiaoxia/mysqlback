#!/bin/bash


##检查targetcli是否安装
chta(){
t=$(rpm -qa | grep targetcl)
if [ -z $t ];then
   yum -y install targetcli
else
   echo "targetcl installed!"
fi
}


##检查expect是否安装
chex(){
y=$(rpm -qa | grep expect)
if [ -z $y ];then
   yum -y install expect 
else 
   echo "expect installed!"
fi
}

##检查iscsi-initiator-utils是否安装
chis(){
i=$(rpm -qa | grep iscsi)
if [ -z "$i" ];then
   yum -y install iscsi-initiator-utils 
else 
   echo "iscsi-initiator-utils installed!"
fi
}

##检查device-mapper-multipath是否安装
chmu(){
m=$(rpm -qa | grep multipath)
if [ -z "$m" ];then
   yum -y device-mapper-multipath
else 
   echo "device-mapper-multipath installed!"
fi
}

##配置ISCSI服务端

tt(){
chta
chex
read -p "please input a name:" a
read -p "please input a device:" b
read -p "please input a iqn_name:" n
read -p "please input a client_name:" x

expect << EOF
spawn targetcli
expect "/> " {send "backstores/block create $a $b\r"}
expect "/> " {send "iscsi/ create $n\r"}
expect "/> " {send "iscsi/$n/tpg1/acls create $x\r"}
expect "/> " {send "iscsi/$n/tpg1/luns create /backstores/block/$a\r"}
expect "/> " {send "saveconfig\r"}
expect "/> " {send "exit\r"}
expect "/> " {send "exit\r"}
EOF
systemctl restart target
systemctl enable target
}



##发现ISCSI
disc(){
read -p "ip address:" add 
iscsiadm --mode discoverydb --type sendtargets --portal $add:3260 --discover
}



##客户端连接ISCSI
cli(){
chis
read -p "please input a iqn_name:" name
echo "InitiatorName=$name" > /etc/iscsi/initiatorname.iscsi
disc
systemctl restart iscsi
systemctl restart iscsid
}

##客户端登陆ISCSI
log(){
read -p "please input a iqn_server:" server 
read -p "ip address:" addr 
iscsiadm --mode node --targetname $server  --portal $addr:3260 --login
}

##客户端注销ISCSI
lout(){
read -p "please input a iqn_server:" s 
read -p "ip address:" r 
iscsiadm --mode node --targetname $s  --portal $addr:3260 --logout
}



##Multipath多路径
Mult(){
for num in {1..2}
do
    disc
done

systemctl restart iscsi
systemctl restart iscsid
read -p "please input a device_name:" dv 
read -p "please input a alias_name:" al 

mpathconf --user_friendly_names n
#cp /usr/share/doc/device-mapper-multipath-0.4.9/multipath.conf /etc
id=$(/usr/lib/udev/scsi_id --whitelisted --device=$dv | awk '{print $1}')
echo " multipaths {
       multipath {
        wwid    \""$id"\"
        alias   \""$al"\"
    }
}
" >> /etc/multipath.conf
systemctl restart multipathd
systemctl enable multipathd
ls -l /dev/mapper/
}





echo -e "\t\033[46m please chose you want to do ！！\033[0m"
echo -e "\t1.Create ISCSI Server!"
echo -e "\t2.Configuretion Client!"
echo -e "\t3.Client login ISCSI!"
echo -e "\t4.Client logout ISCSI !"
echo -e "\t5.Configure Multipath!"
read -p "please input a number:" number

case $number in

1) 
    tt;;
2)  
    cli;;
3)  
    log;;
4)
   lout;;
5) 
  Mult;;
*)
   exit;;
   
esac

