#!/bin/bash
##检查是否安装ipvsadm
chip(){
      a=$(rpm -qa | grep ipvsadm )
      if [ ! -z $a ];then
      echo 'ipvsadm instelled 1'
else
       yum -y install ipvsadm
fi
}

##配置LVS
LVS (){
chip
read -p "please input LVS_Server ip address:" add
read -p "please input mode[NAT(-m) or DR(-g)]:" mode
if [ $mode == "-g" ];then
   SEN
fi
read -p "please input scheduling algorithm (explame rr or wrr):" sa
ipvsadm -A -t $add -s $sa
read -p "please input real_server count number:" num
for x in `seq $num`
do
  read -p "please input Real_Server ip address:" addr
  ipvsadm -a -t $add -r $addr $mode
 
done
ipvsadm -Ln 
ipvsadm -Ln --stats
ipvsadm-save -n > /etc/sysconfig/ipvsadm
systemctl restart ipvsadm
systemctl enable ipvsadm
}



##DR模式时D-Server网络配置
SEN(){
read -p "plese input a network-name:" name
read -p "plese input a network-address:" x
cd /etc/sysconfig/network-scripts
cp -f ifcfg-$name{,:0}
sed -i '/^UUID/d' ifcfg-$name:0
sed -i '/^NAME/s/'$name'/'$name':0/' ifcfg-$name:0
sed -i '/^DEVICE/s/'$name'/'$name':0/' ifcfg-$name:0
sed -i '/^IPADDR/s/=.*/='$x'/' ifcfg-$name:0
systemctl restart network

}

##DR模式时R-Server网络配置
CLN(){
read -p "plese input a network-name:" n
read -p "plese input a network-address:" c
cd /etc/sysconfig/network-scripts
cp -f ifcfg-$n{,:0}
sed -i '/^DEVICE/s/'$n'/'$n':0/' ifcfg-$n:0
sed -i '/^IPADDR/s/=.*/='$c'/' ifcfg-$n:0
sed -i '/^NETMASK/s/=.*/=255.255.255.255/' ifcfg-$n:0
sed -i '/^NETWORK/s/=.*/='$c'/' ifcfg-$n:0
sed -i '/^BROADCAST/s/=.*/='$c'/' ifcfg-$n:0
sed -i '/^NAME/s/=.*/='$n':0/' ifcfg-$n:0
sys
systemctl restart network

}

##配置客户端忽略ARP广播，不做任何回应，回环地址也不宣告自己的ip
sys(){
echo "net.ipv4.conf.all.arp_ignore = 1" >> /etc/sysctl.conf
echo "net.ipv4.conf.$n.arp_ignore = 1" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.arp_announce = 2" >> /etc/sysctl.conf
echo "net.ipv4.conf.$n.arp_announce = 2" >> /etc/sysctl.conf
}

##检查keepalived 是否安装
chk(){
ke=$(rpm -qa | grep keepalived)
if [ ! -z $ke ];then
   echo 'keepalived instelled'
else
    yum -y install keepalived
fi
}


##修改Keepalived.conf配置文件
kec(){
read -p "please input virtual_ipaddress:" vip
sed -i '35,$d' /etc/keepalived/keepalived.conf
sed -i '30,32d' /etc/keepalived/keepalived.conf
sed -i '/vrrp_strict/s/^/#/' /etc/keepalived/keepalived.conf
sed -i "/virtual_ipaddress/a$vip" /etc/keepalived/keepalived.conf
}

##keepalived 服务
kes(){
systemctl start keepalived
systemctl enable keepalived
}

##设置keepalived主服务器
#kemaster(){
#kec
#sed -i '/priority/s/100/150/' /etc/keepalived/keepalived.conf
#kes
#}

##设置keepalived备用服务器
#keslave(){
#kec
#sed -i '/state/s/MASTER/BACKUP/' /etc/keepalived/keepalived.conf
#kes
#}

##选择服务器是主是备
server-mode(){
read -p "choose (1.MASTER or 2.BACKUP)please input number(1-2):" shu
case $shu in 
1) 
   sed -i '/priority/s/100/150/' /etc/keepalived/keepalived.conf;;
2)
   sed -i '/state/s/MASTER/BACKUP/' /etc/keepalived/keepalived.conf;;
*) 
 ;;

esac

}


##配置Keepalive+LVS
Keealive-LVS(){
chip
chk
read -p "please input Virtual_ipaddress:" vir
read -p "please input Virtual_ipaddress port:" port
read -p "please input Real_server ipaddress and port:" rel1
read -p "please input Other Real_server ipaddress and port:" rel2
read -p "please input mode[NAT(-m) or DR(-g)]:" mode
read -p "please input scheduling algorithm (explame rr or wrr):" sa
sed -i '109,$d' /etc/keepalived/keepalived.conf
sed -i '73,84d' /etc/keepalived/keepalived.conf
sed -i '82,89d' /etc/keepalived/keepalived.conf
sed -i '36,60d' /etc/keepalived/keepalived.conf
sed -i '30,32d' /etc/keepalived/keepalived.conf
sed -i '/sorry_server/d' /etc/keepalived/keepalived.conf
sed -i '/vrrp_strict/s/^/#/' /etc/keepalived/keepalived.conf
sed -i '/persistence/s/^/#/' /etc/keepalived/keepalived.conf
sed -i "/virtual_ipaddress/a$vir" /etc/keepalived/keepalived.conf
sed -i 's/HTTP_GET/TCP_CHECK/' /etc/keepalived/keepalived.conf
sed -i '/virtual_server 10.10.10.2 1358/s/10.10.10.2 1358/'$vir' '$port'/' /etc/keepalived/keepalived.conf
sed -i "/real_server 192.168.200.2 1358/s/192.168.200.2 1358/$rel1/" /etc/keepalived/keepalived.conf
sed -i "/real_server 192.168.200.3 1358/s/192.168.200.3 1358/$rel2/" /etc/keepalived/keepalived.conf
server-mode
case $mode in
NAT)
   ;;
DR) 
   sed -i '/lb_kind NAT/s/NAT/'$mode'/' /etc/keepalived/keepalived.conf;;
*) 
   ;;
esac

case $sa in
rr)
  ;;
*)
  
   sed -i '/lb_algo rr/s/rr/'$sa'/' /etc/keepalived/keepalived.conf;;
esac
kes
}

##检查是否安装Haproxy
chh(){
ha=$(rpm -qa | grep haproxy)
if [ ! -z $ha ];then
   echo 'Haproxy installed !'
else
   yum -y install haproxy
fi
}

##更改Haproxy.cfg文件
chap(){
sed -i '/main/,$d' /etc/haproxy/haproxy.cfg
echo "listen stats
    bind 0.0.0.0:80
    stats refresh 30s
    stats uri /stats
    stats realm Haproxy Manager
    stats auth admin:admin
    
listen web_backend 0.0.0.0:80
    cookie SERVERID rewrite
    balance roundrobin " >> /etc/haproxy/haproxy.cfg
read -p "please input backend conut number:" count
for i in `seq $count`
do
  read -p "please input a name:" name
  read -p "please input ip address and port:" s
  echo "server $name $s cookie app1inst1 check inter 2000 rise 2 fall 5
" >> /etc/haproxy/haproxy.cfg
done

systemctl restart haproxy
systemctl enable haproxy

}













echo "1.Configure LVS-Proxy-Server!"
echo "2.Configure LVS-DR-Client Network!"
echo "3.Configure Keepalived-Server!"
echo "4.Configure Keepalived+LVS!"
echo "5.Configure Haproxy-Server!"

read -p "please input a number:" nu

case $nu in

1) 
  LVS;;
2)
 CLN;;
3)
 chk
 kec
 server-mode
 kes;;
4)
 Keealive-LVS;;
5)
 chh
 chap;;
*)
 exit;;

esac


