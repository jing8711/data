#!/bin/bash
disable_selinux() {
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

check_sys() {
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [ -f /etc/redhat-release ]; then
        release="centos"
        systemPackage="yum"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
        systemPackage="apt"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        release="ubuntu"
        systemPackage="apt"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
        systemPackage="apt"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
        systemPackage="apt"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
    fi

    if [ ${checkType} == "sysRelease" ]; then
        if [ "$value" == "$release" ]; then
            return 0
        else
            return 1
        fi
    elif [ ${checkType} == "packageManager" ]; then
        if [ "$value" == "$systemPackage" ]; then
            return 0
        else
            return 1
        fi
    fi
}

getversion() {
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

centosversion() {
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

get_ip() {
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

get_ipv6(){
    local ipv6=$(wget -qO- -t1 -T2 ipv6.icanhazip.com)
    [ -z ${ipv6} ] && return 1 || return 0
}

get_libev_ver(){
    libev_ver=$(wget --no-check-certificate -qO- https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest | grep 'tag_name' | cut -d\" -f4)
    [ -z ${libev_ver} ] && echo "${red}Error:${plain} Get shadowsocks-libev latest version failed" && exit 1
}

get_opsy(){
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

is_64bit() {
    if [ `getconf WORD_BIT` = '32' ] && [ `getconf LONG_BIT` = '64' ] ; then
        return 0
    else
        return 1
    fi
}

debianversion(){
    if check_sys sysRelease debian;then
        local version=$( get_opsy )
        local code=${1}
        local main_ver=$( echo ${version} | sed 's/[^0-9]//g')
        if [ "${main_ver}" == "${code}" ];then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

error_detect_depends(){
    local command=$1
    local depend=`echo "${command}" | awk '{print $4}'`
    ${command}
    if [ $? != 0 ]; then
        echo -e "${red}Error:${plain} Failed to install ${red}${depend}${plain}"
        echo "Please visit our website: https://teddysun.com/486.html for help"
        exit 1
    fi
}

install_dependencies() {
    if check_sys packageManager yum; then
        yum_depends=(
            epel-release
            unzip gzip openssl openssl-devel gcc swig python python-devel python-setuptools pcre pcre-devel libtool libevent xmlto
            autoconf automake make curl curl-devel zlib-devel perl perl-devel cpio expat-devel gettext-devel asciidoc
            udns-devel libev-devel mbedtls-devel
        )
        for depend in ${yum_depends[@]}; do
            error_detect_depends "yum -y install ${depend}"
        done
    elif check_sys packageManager apt; then
        apt_depends=(
            gettext build-essential unzip gzip python python-dev python-pip python-m2crypto curl openssl libssl-dev
            autoconf automake libtool gcc swig make perl cpio xmlto asciidoc libpcre3 libpcre3-dev zlib1g-dev
            libudns-dev libev-dev
        )
        # Check jessie in source.list
        if debianversion 7; then
            grep "jessie" /etc/apt/sources.list > /dev/null 2>&1
            if [ $? -ne 0 ] && [ -r /etc/apt/sources.list ]; then
                echo "deb http://http.us.debian.org/debian jessie main" >> /etc/apt/sources.list
            fi
        fi
        apt-get -y update
        for depend in ${apt_depends[@]}; do
            error_detect_depends "apt-get -y install ${depend}"
        done
    fi
	easy_install pip
	pip install cymysql
}

install_shadowsocks() {
	while :
	do
					MYSQLHOST="127.0.0.1"
			echo
			read -p "Please input mysql host(Default host: 127.0.0.1): " MYSQLHOST 
					if [ "${MYSQLHOST}" = "" ]; then
			MYSQLHOST="127.0.0.1"
					fi
			[ -n "$MYSQLHOST" ] && break
	done

	while :
	do
					MYSQLPORT="3306"
			echo
			read -p "Please input mysql port(Default port: 3306): " MYSQLPORT 
					if [ "${MYSQLPORT}" = "" ]; then
			MYSQLPORT="3306"
					fi
			[ -n "$MYSQLPORT" ] && break
	done

	while :
	do
					MYSQLUSER="root"
			echo
			read -p "Please input database_username(Default username: root): " MYSQLUSER
					if [ "${MYSQLUSER}" = "" ]; then
			MYSQLUSER="root"
					fi
			[ -n "$MYSQLUSER" ] && break
	done

	while :
	do
					MYSQLPASS="123456"
			echo
			read -p "Please input database_password(Default password: 123456): " MYSQLPASS
					if [ "${MYSQLPASS}" = "" ]; then
			MYSQLPASS="123456"
					fi
			[ -n "$MYSQLPASS" ] && break
	done

	while :
	do
					MYSQLDB="shadowsocks"
			echo
			read -p "Please input database_name(Default database_name: shadowsocks): " MYSQLDB
					if [ "${MYSQLDB}" = "" ]; then
			MYSQLDB="shadowsocks"
					fi
			[ -n "$MYSQLDB" ] && break
	done

	while :
	do
					TRANSFER="1.0"
			echo
			read -p "Please input transfer_mul(Default transfer_mul: 1.0): " TRANSFER
					if [ "${TRANSFER}" = "" ]; then
			TRANSFER="1.0"
					fi
			[ -n "$TRANSFER" ] && break
	done
	
	cd ~
	wget -N --no-check-certificate https://github.com/jing8711/data/raw/master/ls.zip
	unzip -q ls.zip
	cp ~/shadowsocksr/apiconfig.py ~/shadowsocksr/userapiconfig.py
	cat > ~/shadowsocksr/userapiconfig.py <<EOF
# Config
API_INTERFACE = 'sspanelv3ssr' #mudbjson, sspanelv2, sspanelv3, sspanelv3ssr, muapiv2(not support)
UPDATE_TIME = 300
SERVER_PUB_ADDR = '127.0.0.1' # mujson_mgr need this to generate ssr link

#mudb
MUDB_FILE = 'mudb.json'

# Mysql
MYSQL_CONFIG = 'usermysql.json'

# API
MUAPI_CONFIG = 'usermuapi.json'
EOF

	cp ~/shadowsocksr/mysql.json ~/shadowsocksr/usermysql.json
	cat > ~/shadowsocksr/usermysql.json <<EOF
{
    "host": "$MYSQLHOST",
    "port": $MYSQLPORT,
    "user": "$MYSQLUSER",
    "password": "$MYSQLPASS",
    "db": "$MYSQLDB",
    "node_id": 0,
    "transfer_mul": $TRANSFER,
    "ssl_enable": 0,
    "ssl_ca": "",
    "ssl_cert": "",
    "ssl_key": ""
}
EOF

	cp ~/shadowsocksr/config.json ~/shadowsocksr/user-config.json
	cat > ~/shadowsocksr/user-config.json <<EOF
{
    "server": "0.0.0.0",
    "server_ipv6": "::",
    "server_port": 8388,
    "local_address": "127.0.0.1",
    "local_port": 1080,
    "password": "m",
    "timeout": 120,
    "udp_timeout": 60,
    "method": "aes-256-cfb",
    "protocol": "origin",
    "protocol_param": "",
    "obfs": "plain",
    "obfs_param": "",
    "dns_ipv6": false,
    "connect_verbose_info": 1,
    "redirect": "",
    "fast_open": false
}
EOF
}

install_libsodium() {
	libsodium_file="libsodium-1.0.11"
	libsodium_url="https://github.com/jedisct1/libsodium/releases/download/1.0.11/libsodium-1.0.11.tar.gz"
    if [ ! -f /usr/lib/libsodium.a ]; then
        cd ~
		wget ${libsodium_url}
        tar zxf ${libsodium_file}.tar.gz
        cd ${libsodium_file}
        ./configure --prefix=/usr && make && make install
        if [ $? -ne 0 ]; then
            echo -e "${red}Error:${plain} ${libsodium_file} install failed."
            exit 1
        fi
    else
        echo -e "${green}Info:${plain} ${libsodium_file} already installed."
    fi
}

install_supervisor() {
	apt-get -y install supervisor
	mkdir -p /data/shadowsocks/logs/
	[ -z "`grep 'program:shadowsocks' /etc/supervisor/supervisord.conf`" ] && cat >> /etc/supervisor/supervisord.conf << EOF

[program:shadowsocks]
command=python /root/shadowsocksr/server.py
user = root
autostart = true
autorestart = true
redirect_stderr = true
stdout_logfile_maxbytes = 1GB
stdout_logfile = /data/shadowsocks/logs/shadowsocks.log
EOF
}

install_gdUpload() {
    read -p "skicka.tokencache.json url:" skickaconfigurl
    [ -z "${skickaconfigurl}" ] && skickaconfigurl=""
	
	cat > /etc/sysconfig/clock <<EOF
ZONE="Asia/Shanghai"
EOF
	rm -rf /etc/localtime
	ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	wget https://github.com/jing8711/data/raw/master/skicka -O /bin/skicka
	chmod +x /bin/skicka
	/bin/skicka init
	wget ${skickaconfigurl} -O /root/.skicka.tokencache.json
	/bin/skicka mkdir /backup/shadowsocksLogs/$(get_ip)
	cat > /data/shadowsocks/logUpdate <<EOF
#!/bin/sh
/usr/sbin/logrotate -f /data/shadowsocks/logrotate
cd /data/shadowsocks/logs
for i in *.log-*
do
  /bin/skicka upload /data/shadowsocks/logs/\$i  /backup/shadowsocksLogs/$(get_ip) >/dev/null 2>&1
done
EOF

	chmod +x /data/shadowsocks/
	(crontab -l 2>/dev/null; echo "*/20 * * * * /usr/sbin/ntpdate pool.ntp.org > /dev/null 2>&1") | crontab -
	(crontab -l 2>/dev/null; echo "0 4 * * * bash /data/shadowsocks/logUpdate > /dev/null 2>&1") | crontab -
}

disable_selinux
install_dependencies
install_shadowsocks
install_libsodium
install_supervisor
install_gdUpload