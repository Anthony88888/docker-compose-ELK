#!/bin/bash
#Author:   Curry
#Date:     2019-8-26


#根据自己的实际情况调整，此步骤不一定需要执行#
#DNS=192.168.10.5
#DNS1=8.8.8.8

sed -i 's/DNS1=192.168.10.5/DNS1=8.8.8.8/g'  /etc/sysconfig/network-scripts/ifcfg-eth0
systemctl restart network 


#--------------------第一步操作--------------------------#
echo "配置yum源相关操作步骤"
cd /etc/yum.repos.d/  && wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo >/dev/null
sleep 2

echo "清除yum缓存,并安装docker-ce版本,设为开机自动启动"
yum clean all && yum mackcache
yum -y install docker-ce   > /dev/null
systemctl enable docker --now  && sleep 2

if  [ $? -ne 0 ]
  then
      exit 1
fi     

echo "第一步骤docker安装,执行成功!"
sleep 2

#-----------------------第二步操作-----------------------#
echo "start install docker-compose"
yum -y install epel-release  > /dev/null
yum -y install python-pip    > /dev/null

echo "update pip and install"
pip install --upgrade pip  && pip install docker-compose

echo "cat docker-compose version"
docker-compose --version

if  [ $? -ne 0 ]
  then
      exit 1
fi

echo "第二步骤docker-compose安装,执行成功!"
sleep 2

#--------------------第三步操作--------------------------#
echo "务必调优jvm-vm.max_map_count限制,否则必定失败"

echo 'vm.max_map_count=262144'>/etc/sysctl.conf & sysctl -p 

if  [ $? -ne 0 ]
  then
      exit 1
fi

echo "第三步骤JVM调优步骤,执行成功!"
sleep 2


#--------------------第四步操作--------------------------#
cat > /root/docker-compose.yml << EOF
version: '2.2'
services:
  kibana:
    image: docker.elastic.co/kibana/kibana:7.3.0
    container_name: kibana73
    environment:
      - I18N_LOCALE=zh-CN
      - XPACK_GRAPH_ENABLED=true
      - TIMELION_ENABLED=true
      - XPACK_MONITORING_COLLECTION_ENABLED="true"
    ports:
      - "5601:5601"
    networks:
      - es73net
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.3.0
    container_name: es73
    environment:
      - cluster.name=geektime
      - node.name=es73
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - discovery.seed_hosts=es73
      - cluster.initial_master_nodes=es73
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - es73data1:/usr/share/elasticsearch/data
    ports:
      - 9200:9200
    networks:
      - es73net


volumes:
  es73data1:
    driver: local

networks:
  es73net:
    driver: bridge
EOF


cd /root/ && docker-compose up 

if  [ $? -ne 0 ]
  then
      exit 1
fi

echo "第四步全部流程部署完成!"
