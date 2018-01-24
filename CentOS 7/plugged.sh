#!/bin/bash

# GLOBALS
FILEVER="1.5"
DOMAIN_NAME=
USER_NAME=
PASSWORD=
PWD="$(dirname "$(realpath "$0")")"
LOGFILE="${PWD}/plugged.log"
PHPVER=
declare -a SERVICES=(
"httpd"
"mariadb"
"vsftpd"
)

php_check(){
    if ins_check php; then
        PHPVER=$(php -v | head -n 1 | cut -d " " -f 2 | cut -c 1,3)
    fi
}

ins_check(){
    INPUT=$1
    rpm -qa | grep "$INPUT" > /dev/null
    return $?
}

intexit(){
    # Allows clean exit via Ctrl-C
    kill -HUP -$$
}

hupexit(){
    # Allows clean exit via Ctrl-C
    echo
    echo "Interrupted"
    echo
    exit
}

repeat(){
    # Repeats a string $num times.
    # Usage:
    # repeat "$str" "$num"
    # repeat "Ha" 10

    str=$1
    num=$2
    printf "%0.s${str}" $(seq 1 $num)
}

title(){
    # Pretty prints the given string with preset but adjustable borders.
    # Default output for "$STRING" is:

    # +------------------+
    # |    plugged.sh    |
    # +------------------+


    # Additional parameters can be added to override default from structure.

    # $DASH = Top and bottom elements => Default value = -
    # $SIDE = Left and right elements => Default value = |
    # $CORNER = Corner elements => Default value = +

    # If only $DASH is set, automatically sets $SIDE and $CORNER to value of $DASH.

    # Usage:
    # title "$STRING" "$DASH" "$SIDE" "$CORNER"
    # title "nfparse v0.1"
    # title "nfparse v0.1" '#'
    # title "nfparse v0.1" '#' '||' 'X'

    OFFSET=5
    NAME=$1
    DASH=$2
    SIDE=$3
    CORNER=$4

    if [[ -z $2 ]]; then
        DASH='-'
    fi

    if [[ -z $3 ]] && [[ -z $2 ]]; then
        SIDE='|'
    elif [[ -z $3 ]] && [[ ! -z $2 ]]; then
        SIDE=$(echo $DASH)
    fi

    if [[ -z $4 ]] && [[ -z $2 ]]; then
        CORNER='+'
    elif [[ -z $4 ]] && [[ ! -z $2 ]]; then
        CORNER=$(echo $DASH)
    fi

    CHARS=${#NAME}
    CHARSC=$(( CHARS - 2 ))
    WIDTH=$(( CHARSC + OFFSET * 2 ))

    printf $CORNER
    repeat $DASH $WIDTH
    printf $CORNER
    printf '\n'
    printf $SIDE
    repeat ' ' $(( OFFSET - 1 ))
    printf "$NAME"
    repeat ' ' $(( OFFSET - 1 ))
    printf $SIDE
    printf '\n'
    printf $CORNER
    repeat $DASH $WIDTH
    printf $CORNER
    printf '\n'
    echo
    sleep 0.2
}

root_check(){
    if [ $(id -u) != "0" ]; then
        echo "Error: You must be root to run this script, please use root to use this script."
        exit 1
    fi
}

banner(){
    echo "========================================================================="
    echo "Plugged V${FILEVER} for CentOS/RadHat Linux 7"
    echo "========================================================================="
    echo "A tool to auto-compile & install MySQL+PHP on Linux "
    echo ""
    echo "For more information please visit http://www.plugged.in/"
    echo "========================================================================="
}

ranger_set(){
    git clone https://github.com/ranger/ranger.git /tmp/ranger
    (cd /tmp/ranger && make install && cd && ranger --copy-config=all && sed -i "s/set colorscheme default/set colorscheme solarized/g" ~/.config/ranger/rc.conf && sed -i "s/draw_borders false/draw_borders true/g" ~/.config/ranger/rc.conf)
    rm -rf /tmp/ranger
}

prepare(){
    echo "Installing required packages..."
    yum install -y http://rpms.remirepo.net/enterprise/remi-release-7.rpm
    yum install -y yum-utils
    yum-config-manager --enable remi-php${PHPVER}
    if [[ $PHPVER != "54" ]]; then
        yum-config-manager --enable remi
    fi
    #yum upgrade -y
    yum install -y epel-release
    yum install -y ntp git vim-enhanced rsync net-tools wget bind-utils net-tools lsof iptraf tcpdump apachetop
    yum install -y httpd vsftpd mariadb-server php php-mcrypt php-cli php-gd php-curl php-mysql php-ldap php-zip php-fileinfo phpmyadmin
    ranger_set
    echo "Done."
}

ntp_set(){
    echo "Setting timezone to Turkey..."
    rm -rf /etc/localtime
    ln -s /usr/share/zoneinfo/Turkey /etc/localtime
    echo "Done."
    echo "Configuring NTP..."
    sed -i '/server/c\# server' /etc/ntp.conf
    ntp1="ntp1.veriteknik.com"
    ntp2="ntp2.veriteknik.com"
    echo "server $ntp1 iburst" >> /etc/ntp.conf
    echo "server $ntp2 iburst" >> /etc/ntp.conf
    echo "Activating NTP..."
    systemctl start ntpd
    sleep 2
    systemctl enable ntpd
    systemctl stop ntpd
    sleep 2
    ntpd -gq
    systemctl start ntpd
    sleep 2
    ntpq -p
    date
    echo "Done."
}

firewalld_set(){
    echo "Disabling firewalld..."
    systemctl stop firewalld
    systemctl mask firewalld
    echo "Done."
}

selinux_set(){
    echo "Disabling SELinux for the installation..."
    setenforce 0
    sed -i '/SELINUX=enabled/c\SELINUX=disabled' /etc/ntp.conf
    echo "Done."
}

ipv6_set(){
    echo "Disabling IPv6..."
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
    sysctl -p
    systemctl restart network
    echo "Done."
}

nginx_set(){
    if ins_check nginx; then
        echo "nginx is installed"
        nginx -v
    else
        echo "Installing nginx..."
        yum install -y nginx python-pip
        pip install ngxtop
        echo "Done."
    fi
    cat > /etc/nginx/nginx.conf <<EOF
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;
}
EOF
    htstat="1"
    for conf in /etc/httpd/conf.d/z_*; do
        [ -e "$conf" ] && htstat="0"
        break
    done
    if [[ $htstat == 0 ]]; then
        files=$(find /etc/httpd/conf.d/ -name 'z_*')
        for file in "${files[@]}"; do
            sed -i "s/^<VirtualHost .*/<VirtualHost 127.0.0.1:8080>/g" $file
        done
        nginx_make_config
    fi
    sed -i "s/^Listen .*/Listen 127.0.0.1:8080/g" /etc/httpd/conf/httpd.conf
    sed -i "s/^ServerName .*/ServerName 127.0.0.1:8080/g" /etc/httpd/conf/httpd.conf
    service_status=$(systemctl is-active nginx)
    if [[ $service_status != "active" ]]; then
        systemctl start nginx
    else
        systemctl restart nginx
    fi
}

nginx_check_config(){
    for conf in /etc/nginx/conf.d/z_*; do
        [ -e "$conf" ] && return 0 || return 1
        break
    done
}

nginx_make_config(){
    files=($(ls /etc/httpd/conf.d | grep "^z_"))

    for file in "${files[@]}"; do
        if [[ ! -f "/etc/nginx/conf.d/${file}" ]]; then
            touch /etc/nginx/conf.d/${file}
            nginx_domain=$(grep 'ServerName' /etc/httpd/conf.d/${file} | awk '{print $2}')
            cat > "/etc/nginx/conf.d/${file}" <<EOF
server {
    listen       80;
    server_name $DOMAIN_NAME;
    location / {
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header Host \$host;
        proxy_pass http://127.0.0.1:8080;
    }
    error_page 404 /404.html;
    location = /40x.html {
    }
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
    }
}
EOF
        fi
    done
}

httpd_set(){
    CONF=/etc/httpd/conf.d/z_$USER_NAME.conf
    touch $CONF
    IP=$(curl -s icanhazip.com)

    cat > "$CONF" <<EOF
<VirtualHost $IP:80>
        ServerAdmin root@$DOMAIN_NAME
        DocumentRoot /home/$USER_NAME/public_html/
        ServerName $DOMAIN_NAME
        ServerAlias *.$DOMAIN_NAME $IP
        ErrorLog /home/$USER_NAME/logs/error.log
        CustomLog /home/$USER_NAME/logs/$DOMAIN_NAME.log common

        ErrorDocument 403 /403.php
        ErrorDocument 404 /404.php

        ScriptAlias /cgi-bin/ "/home/$USER_NAME/cgi-bin/"
        <Directory "/home/$USER_NAME/cgi-bin/">
                AllowOverride None
                Options None
                Order deny,allow
                Allow from all
        </Directory>

        <Directory "/home/$USER_NAME/public_html">
                order deny,allow
                allow from all
                Options FollowSymLinks
				AllowOverride All
                SetOutputFilter DEFLATE

                AddOutputFilterByType DEFLATE text/plain
                AddOutputFilterByType DEFLATE text/xml
                AddOutputFilterByType DEFLATE application/xhtml+xml
                AddOutputFilterByType DEFLATE text/css
                AddOutputFilterByType DEFLATE application/xml
                AddOutputFilterByType DEFLATE image/svg+xml
                AddOutputFilterByType DEFLATE application/rss+xml
                AddOutputFilterByType DEFLATE application/atom_xml
                AddOutputFilterByType DEFLATE application/x-javascript
                AddOutputFilterByType DEFLATE application/x-httpd-php
                AddOutputFilterByType DEFLATE application/x-httpd-fastphp
                AddOutputFilterByType DEFLATE application/x-httpd-eruby
                AddOutputFilterByType DEFLATE text/html
                </Directory>
        SuexecUserGroup $USER_NAME $USER_NAME

        php_admin_value open_basedir /home/$USER_NAME:/tmp:/usr/lib64/php/modules:/usr/share/phpMyAdmin/:/usr/share/php
        php_admin_value error_log  /home/$USER_NAME/logs/php_error.log

</VirtualHost>
EOF
    sed -i "s/#ServerName www.example.com:80/ServerName ${IP}:80/g" /etc/httpd/conf/httpd.conf
    if [[ $PHPVER == "54" ]]; then
        sed -i "s/php_admin_value open_basedir/#php_admin_value open_basedir/g" $CONF
    fi
    if ins_check nginx; then
        sed -i "s/^<VirtualHost .*/<VirtualHost 127.0.0.1:8080>/g" $CONF
        nginx_make_config
    fi
}

add_wordpress(){
	cd /home/${USER_NAME}
	wget https://wordpress.org/latest.tar.gz
	tar -xzvf latest.tar.gz > /dev/null
	mv wordpress/* /home/${USER_NAME}/public_html
	rm -rf latest.tar.gz wordpress/
	sed -i "s/database_name_here/$USER_NAME/g" ${PWD}/public_html/wp-config-sample.php
	sed -i "s/username_here/$USER_NAME/g" ${PWD}/public_html/wp-config-sample.php
	sed -i "s/password_here/$PASSWORD/g" ${PWD}/public_html/wp-config-sample.php 
	mv public_html/wp-config-sample.php public_html/wp-config.php
	chown -R ${USER_NAME}: /home/${USER_NAME}
}

phpmyadmin_set(){
    SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    sed -i "s/.*blowfish_secret.*/\$cfg[\'blowfish_secret\'] = \'${SECRET}\';/" /etc/phpMyAdmin/config.inc.php
    if [[ $PHPVER == "54" ]]; then
        sed -i "s/Require ip 127.0.0.1/Require all granted/g" /etc/httpd/conf.d/phpMyAdmin.conf
        sed -i "s/Require ip ::1/#Require ip ::1/g" /etc/httpd/conf.d/phpMyAdmin.conf
    else
        sed -i "s/Require local/Require all granted/g" /etc/httpd/conf.d/phpMyAdmin.conf
    fi
}

add_user(){
    useradd -m -G wheel -s /bin/bash $USER_NAME
    echo $PASSWORD | /usr/bin/passwd --stdin $USER_NAME
    chmod 755 /home/$USER_NAME
    mkdir /home/$USER_NAME/public_html
    echo "<?php phpInfo(); ?>" > /home/$USER_NAME/public_html/index.php
    mkdir /home/$USER_NAME/logs
    touch /home/$USER_NAME/logs/{php_error.log,error.log,$DOMAIN_NAME.log}
    chown -R $USER_NAME: /home/$USER_NAME
    chown apache: /home/$USER_NAME/logs/php_error.log
}

mycnf_set(){
    echo "[client]" > /root/.my.cnf
    echo "user=root" >> /root/.my.cnf
    echo "password=$PASSWORD" >> /root/.my.cnf
}

mysql_set_root(){
    systemctl start mariadb
	mysqladmin --user=root --password= password "${PASSWORD}" 1> /dev/null 2> /dev/null
	echo "UPDATE mysql.user SET password=PASSWORD('${PASSWORD}') WHERE user='root';"> mysql.temp;
	echo "UPDATE mysql.user SET password=PASSWORD('${PASSWORD}') WHERE password='';">> mysql.temp;
	echo "DROP DATABASE IF EXISTS test;" >> mysql.temp
	echo "FLUSH PRIVILEGES;" >> mysql.temp;
	mysql --user=root --password=${PASSWORD} < mysql.temp;
	rm -f mysql.temp;
    systemctl stop mariadb
}

mysql_set_user(){
    systemctl start mariadb
	echo "CREATE DATABASE ${USER_NAME};"> mysql.temp;
	echo "GRANT ALL PRIVILEGES ON ${USER_NAME}.* TO '${USER_NAME}'@'localhost' IDENTIFIED BY '${PASSWORD}';">> mysql.temp;
	echo "FLUSH PRIVILEGES;" >> mysql.temp;
	mysql --user=root < mysql.temp;
	rm -f mysql.temp;
    systemctl stop mariadb
}

ssh_key_add(){
    # Insert your organizations public keys here
    SSHKEYS=''
    if [[ ! -d "/root/.ssh" ]]; then
        mkdir ~/.ssh
    fi
    echo "$SSHKEYS" >> ~/.ssh/authorized_keys
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys
}

services_set(){
    for service in "${SERVICES[@]}"; do
        systemctl start $service
        systemctl enable $service
    done
    if ins_check nginx; then
        systemctl start nginx
    fi
}

services_reset(){
    for service in "${SERVICES[@]}"; do
        systemctl restart $service
    done
    if ins_check nginx; then
        systemctl restart nginx
    fi
}

user_check(){
    USER=$1
    grep $USER /etc/passwd > /dev/null
    [ $? -eq 0 ] && return $TRUE || return $FALSE
}

var_get(){
    TYPE=$1
    php_check
    if [[ $TYPE == "fresh" ]] && [[ -z $PHPVER ]]; then
        echo "Choose PHP version:"
        select choices in "7.2" "7.1" "7.0" "5.4"; do
            case $choices in
                "7.2" )
                    PHPVER="72"
                    break
                    ;;
                "7.1" )
                    PHPVER="71"
                    break
                    ;;
                "7.0" )
                    PHPVER="70"
                    break
                    ;;
                "5.4" )
                    PHPVER="54"
                    break
                    ;;
            esac
        done
        read -p "MySQL Root Password: " PASSWORD
        if [[ -z $PASSWORD ]]; then
            echo "Set proper values."
            var_get $TYPE
        fi

    elif [[ $TYPE == "fresh" ]]; then
        phpver_pretty=$(php -v | grep cli | awk '{print $2}')
        echo "PHP version ${phpver_pretty} detected."
        sleep 0.2
        read -p "MySQL Root Password: " PASSWORD
        if [[ -z $PASSWORD ]]; then
            echo "Set proper values."
            var_get $TYPE
        fi
    elif [[ $TYPE == "addition" ]] && [[ -z $PHPVER ]]; then
        echo "No PHP detected. Run fresh installation first."
        menu
    elif [[ $TYPE == "addition" ]]; then
        sleep 0.2
        read -p "Domain: " DOMAIN_NAME
        read -p "Password: " PASSWORD
        if [[ -z $DOMAIN_NAME ]] || [[ -z $PASSWORD ]]; then
            echo -e "Set proper values."
            var_get $TYPE
        fi
        USER_NAME=$(echo $DOMAIN_NAME | awk -F'.' '{print $1}')
        if [[ $USER_NAME == "www" ]]; then
            USER_NAME=$(echo $DOMAIN_NAME | awk -F'.' '{print $2}')
            DOMAIN_NAME=$(echo $DOMAIN_NAME | cut -d'.' -f 2-)
        fi
        if  user_check $USER_NAME; then
            echo "This user exists."
            var_get $TYPE
        fi
    fi
}

convert_to_nginx(){
    echo "Converting to apache+nginx..."
    if [[ ! -d /etc/plugged ]]; then
        mkdir /etc/plugged
    fi
    for folder in /etc/plugged/httpd_*; do
        [ -e "$folder" ] && rm -rf $folder
        break
    done
    rsync -avh --progress /etc/httpd /etc/plugged/httpd_pure
    nginx_set
    echo "Done."
}

convert_to_apache(){
    echo "Converting to pure apache..."
    echo "Done."
}

fresh_pa(){
    title "Fresh Installation Starting [Pure Apache]..."
    var_get fresh
    title "Installing..."
    ssh_key_add
    firewalld_set
    selinux_set
    ipv6_set
    ntp_set
    prepare
    phpmyadmin_set
    mycnf_set
    mysql_set_root
    services_set	
    title "Completed."
}

fresh_an(){
    title "Fresh Installation Starting [Apache+Nginx]..."
    var_get fresh
    title "Installing..."
    ssh_key_add
    firewalld_set
    selinux_set
    ipv6_set
    ntp_set
    prepare
    phpmyadmin_set
    mycnf_set
    mysql_set_root
    nginx_set
    services_set
    title "Completed."
}

addition(){
    title "Domain Setup Starting..."
    var_get addition
    title "Configuring..."
    add_user
    httpd_set
    mysql_set_user
    services_reset
    title "Completed."
}
addition_wordpress(){
	addition
	echo "Installing WordPress"
	add_wordpress
    title "Completed."
}

menu(){
    root_check
    title "plugged.sh v${FILEVER}"
    banner
    echo
    title "Menu"
    echo

    declare -a OPTS=(
    )
    declare -A OPTS_FUNCS=(
    ["Fresh Installation (Apache)"]="fresh_pa"
    ["Fresh Installation (Apache+Nginx)"]="fresh_an"
    ["Add Domain/User/Database"]="addition" 
    ["Add Domain/User/Database (WordPress)"]="addition_wordpress"
    ["Switch to Apache+Nginx Reverse Proxy"]="to_nginx"
    ["Switch to Apache Only"]="to_apache"
    ["Quit"]="bye"
    )

    if ins_check mysql && ins_check httpd && ins_check nginx; then
        echo "Installed: apache+nginx & mysql"
        echo
        OPTS+=(
        "Add Domain/User/Database"
        "Add Domain/User/Database (WordPress)"
        "Switch to Apache Only"
        )
    elif ins_check mysql && ins_check httpd; then
        echo "Installed: apache & mysql"
        echo
        OPTS+=(
        "Add Domain/User/Database"
        "Add Domain/User/Database (WordPress)"
        "Switch to Apache+Nginx Reverse Proxy"
        )
    else
        OPTS+=(
        "Fresh Installation (Apache)"
        "Fresh Installation (Apache+Nginx)"
        )
    fi


    OPTS+=("Quit")
    sleep 0.2
    select opt in "${OPTS[@]}"; do
        case $opt in
            "")
                menu
                break
                ;;
            *)
                CALL="${OPTS_FUNCS[$opt]}"
                break
                ;;
        esac
    done

    case $CALL in
        fresh_pa )
            fresh_pa
            menu
            break
            ;;
        fresh_an )
            fresh_an
            menu
            break
            ;;
        addition )
            addition
            menu
            break
            ;;
		addition_wordpress )
            addition_wordpress
            menu
            break
            ;;
        to_nginx )
            convert_to_nginx
            menu
            break
            ;;
        to_apache )
            convert_to_apache
            menu
            break
            ;;
        bye )
            title "Goodbye!"
            exit 0
            break
            ;;
    esac
}

main(){
    menu
}

main | tee $LOGFILE
