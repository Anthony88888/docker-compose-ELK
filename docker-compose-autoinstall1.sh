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
echo "######安装epel源等相关包######"
yum -y install epel-release  > /dev/null
yum -y install python-pip    > /dev/null

echo "######更新并且安装pip相关包######"
pip install --upgrade pip  && pip install docker-compose

echo ` docker-compose --version `

if  [ $? -ne 0 ]
  then
      exit 1
fi

echo "第二步骤docker-compose安装,执行成功!"
sleep 2

#--------------------第三步操作--------------------------#
echo "务必调优jvm-vm.max_map_count限制,否则必定失败"

echo 'vm.max_map_count=520000'>/etc/sysctl.conf & sysctl -p 

if  [ $? -ne 0 ]
  then
      exit 1
fi

echo "第三步骤JVM调优步骤,执行成功!"
sleep 2

#--------------------第四步操作--------------------------#
echo "######准备docker-compose的yml文件,并启动服务，后台运行!#######"

cat > /root/docker-compose.yml << EOF
version: '2.2'
services:
  cerebro:
    image: lmenezes/cerebro:0.8.3
    container_name: cerebro
    ports:
      - "9000:9000"
    command:
      - -Dhosts.0.host=http://elasticsearch:9200
    networks:
      - es7net
  kibana:
    image: docker.elastic.co/kibana/kibana:7.1.0
    container_name: kibana7
    environment:
      - I18N_LOCALE=zh-CN
      - XPACK_GRAPH_ENABLED=true
      - TIMELION_ENABLED=true
      - XPACK_MONITORING_COLLECTION_ENABLED="true"
    ports:
      - "5601:5601"
    networks:
      - es7net
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.1.0
    container_name: es7_01
    environment:
      - cluster.name=geektime
      - node.name=es7_01
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - discovery.seed_hosts=es7_01,es7_02
      - cluster.initial_master_nodes=es7_01,es7_02
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - es7data1:/usr/share/elasticsearch/data
    ports:
      - 9200:9200
    networks:
      - es7net
  elasticsearch2:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.1.0
    container_name: es7_02
    environment:
      - cluster.name=geektime
      - node.name=es7_02
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - discovery.seed_hosts=es7_01,es7_02
      - cluster.initial_master_nodes=es7_01,es7_02
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - es7data2:/usr/share/elasticsearch/data
    networks:
      - es7net


volumes:
  es7data1:
    driver: local
  es7data2:
    driver: local

networks:
  es7net:
    driver: bridge
EOF

cd /root/ && docker-compose up  -d

if  [ $? -ne 0 ]
  then
      exit 1
fi

echo "第四步Docker-compose部署ELK执行成功,请开始你的表演!!!!!!"
