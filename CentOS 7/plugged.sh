#!/bin/bash

# GLOBALS
DOMAIN_NAME=
USER_NAME=
PASSWORD=
PWD="$(dirname "$(realpath "$0")")"
LOGFILE="${PWD}/plugged.log"

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
}

root_check(){
    if [ $(id -u) != "0" ]; then
        echo "Error: You must be root to run this script, please use root to use this script."
        exit 1
    fi
}

banner(){
    echo "========================================================================="
    echo "Plugged V0.1 for CentOS/RadHat Linux 7"
    echo "========================================================================="
    echo "A tool to auto-compile & install MySQL+PHP on Linux "
    echo ""
    echo "For more information please visit http://www.plugged.in/"
    echo "========================================================================="
}

usage(){
    echo "Usage: $0 -u username -p password -d domain"
    echo ""
    echo " -u username : Set the LOGIN name"
    echo " -p password : Set the Password"
    echo " -d domain   : Set the Domain"
    echo ""
    exit 1
}

argparse(){
    # call with $@ to pass arguements

    if [ $# -lt 3 ]; then
            usage
        exit -1
    fi

    while [ -n "$1" ] ; do
                case $1 in
                -d | --domain )
                        shift
                        export DOMAIN_NAME=$1
                        ;;
                -u | --user* )
                        shift
                        export USER_NAME=$1
                        ;;
                -p | --pass* )
                        shift
                        export PASSWORD=$1
                        ;;
                -h | --help )
                        usage
                        exit 0
                        ;;
                * )
                        echo "ERROR: Unknown option: $1"
                        echo
                        Usage
                        exit -1
                        ;;
                esac
                shift
    done
}

prepare(){
    echo "Installing required packages..."
    yum install -y epel-release
    yum install -y http://rpms.remirepo.net/enterprise/remi-release-7.rpm
    yum install -y yum-utils
    yum-config-manager --enable remi-php72
    yum-config-manager --enable remi
    #yum upgrade -y
    yum install -y ntp git vim-enhanced rsync net-tools vsftpd httpd mariadb-server
    yum install -y php php-mcrypt php-cli php-gd php-curl php-mysql php-ldap php-zip php-fileinfo phpmyadmin
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
				AllowOverRide All
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

        php_admin_value open_basedir /home/$USER_NAME:/tmp:/usr/lib64/php/modules:/usr/share/phpMyAdmin/
        php_admin_value error_log  /home/$USER_NAME/logs/php_error.log

</VirtualHost>
EOF
    # For phpMyAdmin

    SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
    sed -i "s/.*blowfish_secret.*/\$cfg[\'blowfish_secret\'] = \'${SECRET}\';/" /etc/phpMyAdmin/config.inc.php
    sed -i "s/Require local/Require all granted/g" /etc/httpd/conf.d/phpMyAdmin.conf
    sed -i "s/ServerName www.example.com:80/ServerName ${IP}:80/g" /etc/httpd/conf/httpd.conf
}

add_user(){
    useradd -m -G wheel -s /bin/bash $USER_NAME
    echo $PASSWORD | /usr/bin/passwd --stdin $USER_NAME
    chmod 755 /home/$USER_NAME
    mkdir /home/$USER_NAME/public_html
    echo "<?php phpInfo(); ?>" > /home/$USER_NAME/public_html/index.php
    mkdir /home/$USER_NAME/logs
    touch /home/$USER_NAME/logs/{php_error.log,error.log,$DOMAIN_NAME.log}
    chown -R $USER_NAME: /home/$USER_NAME/public_html
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
	mysql --user=root --password=${PASSWORD} < mysql.temp;
	rm -f mysql.temp;
    systemctl stop mariadb
}

vt_key_add(){
    SSHKEYS='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDRZ2DTvMoKl4IEvY0lVNmfH8CsHZVwCdYjwE0BGV9ngXKaCHp0IhjCGjdmA+WnD/vcvYV8VaVppxc5rxNW9FaorX2MmjLq+jtEKlkHoq+rTpiA7PEx88gfMaruZYpG8FT3QI1yhtSskdpFUkT+djS+JO6mZQNrnIdiNpTI1lVHnu6jQoMkHqp7OBYDlM2YH9S24buGcsWPfcjXSMQAebxrUpa5A3pF+oAhFywbvEZr9pOXBamc81Mwj+7ptwtmk+NJyqc4Sh1Q1yWcMZA0WoYD280t/+F0wKr9hVwciPrA4EBt+sGj0x1VbznoTle5XlARSfOwBmU4zmWGBLsuWc19 ckaraca@veriteknik.com
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD8am213MKgHxsgeEfBS4ALcBihpAfNbFB5CR2esam2tkFT39YAkrDkX6ViCmUPNvg0aiSQU743pN5+v6/qbN3kw1PUiab2zmUE37d3BrXhaB/ud2hXVuV+8JQlTjx3G5XzX+iFzbaxVhaADLayGNFRQ2hJOH0zWxDi4Z414Sqt31r6fAodvCVlPRce5PkNGLY+6fYOw9VsdRiIcm3sTBQj1iH/0UMK1dkKfr9iMCbCu80DCbukq2msP//1OX70EZEklEHuY/ueWb2noO+NkNSac8d7yg7EqJVGZkY44KSiHeiYGq77mnjB6PX3VAMzg8Tt0l3dO+q2mTfD9pRySRvx eaydin@veriteknik.com
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC9KW7Pl1WoVU4ygzs8sArzU1ZRAgK9TAgTzYz8KjDY6HhWdSg5tO378JKvXEPzeTyVrOf8wjoAu64j1bQeEEMZ3tj4x7a2K+pxrBzZ91zFnEC12F2RO37OQhe87zkNzOtrv96T7rLk3PzjW6jRsJCPh2cvf0FBzPfjxJtp4+/m/jzkaeHN3ulj6yZ/MXvnZCjtydhN5BOyMsTAh/oFDTIqfTTsmuZFj2o0FGLMXOPCJvuF6MKPqob3lGFlBqUlfvDusRdWKgGfxionpUMdNy5tYnCC36l9CtPZNnnKbmm5DSDxRGQP6tQvmEZSK7s5s1sORBf/pBUxVbBnAKhBAYet eren@veriteknik
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC6Sjiai+NZcl4qCMMpmfW+5FwAaEOoOe9vpIAtpHOCXCj0v8P2xX4rg+b0EwUhwGQS3/UiLo5mgkFnaiDB8E+p/wHpHovrtYrpX9M5rtTae4vPai4ldNaHsfBTKIgW+EEbDm+RW/wbzdT8yioPzGIdaQ0CR+FyKHPH8SKOKHO17e9RrsraSVzzDhu/MH+krE3/1o0epl1xYaSDSF9lx6HRcMiX/8Dm2+4XM+hUZs0FoxUL2zj51ya2/3z5RgfslhzcDmGRWY03zW49+rlhfHtvNPqwxtEj6kGBPHmf2z+RAvVVsDuAFM+odmznhvfaxT+ptTtLwGFU2dSPkUrzELij tunc@veriteknik.com
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCkswr4ZJirF4Q02nwDEsUG04g3Acq5v/rMTtbXRfSf7P2FRMmevafidw1iM8fuXTuKBshQKryFt7+U7tBYNVOyLW3l8GhUqJ/yoQmw0QzbpmHZdXPPrEO2f9iX6jzdfOX2xtdoPxA/rOCbgKG/NoaBQe9nRMu1aWa5LHPxLzLJOZkLprB9Ano6AtGIaCUuE0qDX54/Va2XjEIgFpWnIy4BLRKyHIWVEz2wj5gCz72IdTfXSazpSOTIoL0w3kIa/v1553/712YSRF/AwP4NUAVrqVsEwLcdcos1vMYluZSK/2Ccnpdrx7LdWdUp/SG7vhKmqRqP3hCutBKOT6sELez9 muratk@veriteknik'
    mkdir ~/.ssh
    echo "$SSHKEYS" >> ~/.ssh/authorized_keys
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys
}

services_set(){
    declare -a services=(
    "httpd"
    "mariadb"
    "vsftpd"
    )

    for service in "${services[@]}"; do
        systemctl start $service
        systemctl enable $service
    done
}

main(){
    title "plugged.sh v0.1"
    echo
    banner
    echo
    root_check
    argparse $@
    vt_key_add
    prepare
    firewalld_set
    selinux_set
    ipv6_set
    ntp_set
    add_user
    #httpd_set
    mycnf_set
    mysql_set_root
    mysql_set_user
    services_set
    title "All done. Please reboot."
}

main $@ | tee $LOGFILE
