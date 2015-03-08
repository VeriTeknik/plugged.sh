#!/bin/env bash

###############################################################################
#     Copyright Plugged.in 2014 All rights reserved
###############################################################################
# This script is for adding users as FTP/SSH accounts and
# MySQL tables and relevant domain settings for apache.
# Runs best with systems installed using the LAMP installer at
# http://plugged.in
#
# Version 0.2
# USE AT YOUR OWN RISK!!!
# Modified for suPHP
###############################################################################


USER_NAME=
PASSWORD=
DOMAIN=
IP=
DBNAME=
DBUSER=
DBPASS=

USER_SHELL=/bin/bash

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script."
    exit 1
fi

Usage(){
    echo "Usage: $0 -u username -p password -d domain -ip IP -dbu dbuser -dbn dbname -dbp dbpass"
    echo ""
    echo " -u username : Set the LOGIN name (FTP user)"
    echo " -p password : Set the Password"
    echo " -d domain : Set the Domain"
    echo " -ip ip : Set the IP address for the domain"
    echo " -dbu dbuser : Set the MySQL User"
    echo " -dbn dbname : Set the MySQL Database Name"
    echo " -dbp dbpass : Set the MySQL User Password"
    echo ""
    exit 1
}

# parse arguments
if [ $# -lt 14 ] ; then
		Usage
	exit -1
fi

while [ -n "$1" ] ; do
 	        case $1 in
 	        -d | --domain )
 	                shift
 	                DOMAIN=$1
 	                ;;
 	        -u | --user* )
 	                shift
 	                USER_NAME=$1
 	                ;;
 	        -p | --pass* )
 	                shift
 	                PASSWORD=$1
 	                ;;
 	        -dbn | --dbname* )
 	                shift
 	                DBNAME=$1
 	                ;;
 	        -dbp | --dbpass* )
 	                shift
 	                DBPASS=$1
 	                ;;
 	        -dbu | --dbuser* )
 	                shift
 	                DBUSER=$1
 	                ;;
 	        -ip | --ip* )
 	                shift
 	                IP=$1
 	                ;;
 	        -h | --help )
 	                Usage
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

echo "FTP/SSH User Name : $USER_NAME"
echo "Domain : $DOMAIN"
echo "FTP/SSH Password : $PASSWORD"
echo "MySQL DB Name : $DBNAME"
echo "MySQL DB User : $DBUSER"
echo "MySQL DB Pass : $DBPASS"
echo "IP ADDRESS : $IP"


isUserExits(){
    grep -x $1 /etc/passwd > /dev/null
    [ $? -eq 0 ] && return $TRUE || return $FALSE
}

createNewUser(){
    /usr/sbin/useradd "$@"
}

if ( ! isUserExits $USER_NAME )
    then
        createNewUser -m -s $USER_SHELL $USER_NAME
         echo $PASSWORD | /usr/bin/passwd --stdin $USER_NAME
         chmod 755 /home/$USER_NAME
    else
        echo "Username \"$USER_NAME\" exists in /etc/passwd"
        exit 3
fi

mkdir /home/$USER_NAME/{public_html,logs}
touch /home/$USER_NAME/logs/{php_error.log,error.log,$DOMAIN.log}
chown -R $USER_NAME:$USER_NAME /home/$USER_NAME
chown $USER_NAME:$USER_NAME /home/$USER_NAME/logs/$DOMAIN.log
chown apache:apache /home/$USER_NAME/logs/php_error.log

CONF=/etc/httpd/conf.d/z_$USER_NAME.conf
touch $CONF

if find /etc/httpd/conf.d -type f -iname "*.conf" | xargs grep -Fxq "NameVirtualHost $IP:80"
    then
    echo "Not adding multiple NameVirtualHost"
    else
    echo "NameVirtualHost $IP:80" > $CONF
fi

cat >> "$CONF" <<EOF
<VirtualHost $IP:80>
        ServerAdmin root@$DOMAIN
        DocumentRoot /home/$USER_NAME/public_html/
        ServerName $DOMAIN
        ServerAlias *.$DOMAIN $IP
        ErrorLog /home/$USER_NAME/logs/error.log
        CustomLog /home/$USER_NAME/logs/$DOMAIN.log common

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

                </Directory>
        suPHP_Engine ON
        suPHP_UserGroup $USER_NAME $USER_NAME
        AddHandler x-httpd-php .php .php3 .php4 .php5
        suPHP_AddHandler x-httpd-php

        php_admin_value open_basedir /home/$USER_NAME:/tmp:/usr/lib64/php/modules:/usr/share/phpmyadmin/
        php_admin_value error_log  /home/$USER_NAME/logs/php_error.log

</VirtualHost>
EOF


#CREATE USER $DBUSER@'localhost' IDENTIFIED BY '$DBPASS';
/usr/bin/mysql <<EOF
CREATE DATABASE IF NOT EXISTS $DBNAME;
GRANT USAGE ON *.* TO '$DBUSER'@'localhost' IDENTIFIED BY '$DBPASS' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
GRANT ALL PRIVILEGES ON $DBNAME.* TO $DBUSER@'localhost';
EOF

service httpd restart

# INSTALLING WORDPRESS

echo "Installing Wordpres..."

cd /home/$USER_NAME/public_html

wget http://wordpress.org/latest.tar.gz .
tar -xvzf latest.tar.gz
mv wordpress/* .
rmdir wordpress
rm -f latest.tar.gz

mv wp-config-sample.php wp-config.php
sed -i "s/^define('DB_NAME',.*/define('DB_NAME', '$DBNAME');/" wp-config.php
sed -i "s/^define('DB_USER',.*/define('DB_USER', '$DBUSER');/" wp-config.php
sed -i "s/^define('DB_PASSWORD',.*/define('DB_PASSWORD', '$DBPASS');/" wp-config.php

chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/public_html

echo "all done!"





