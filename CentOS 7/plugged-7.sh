#!/bin/bash
###############################################################################
#     Copyright Plugged.in 2014 All rights reserved
###############################################################################
# This scirpt installs everything needed to run a web server and
# updates, installs & configures various options of a clearly installed system
#
#
# Version 0.3
# USE AT YOUR OWN RISK!!!
# type the following:
#
# chmod 755 plugged.sh
#
# after this has been done, you can type ./plugged.sh to run the script.
#
# ex: plugged.sh -u example -p password -d example.com
#
###############################################################################

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

repoVer="0.5.3-1"
BASEDIR=/home
USRSHELL=/bin/bash

DOMAIN_NAME=
USER_NAME=
PASSWORD=
IP=
CONF=
## TODO
# logrotate

# Close IPtables
chkconfig iptables off
chkconfig ip6tables off
# Servisleri ac

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install lnmp"
    exit 1
fi

clear
echo "========================================================================="
echo "Plugged V0.2 for CentOS/RadHat Linux 6"
echo "========================================================================="
echo "A tool to auto-compile & install MySQL+PHP on Linux "
echo ""
echo "For more information please visit http://www.plugged.in/"
echo "========================================================================="


Usage(){
    echo "Usage: $0 -u username -p password -d domain"
    echo ""
    echo " -u username : Set the LOGIN name"
    echo " -p password : Set the Password"
    echo ""
    exit 1
}

# parse arguments
if [ $# -lt 6 ] ; then
		Usage
	exit -1
fi

while [ -n "$1" ] ; do
 	        case $1 in
 	        -d | --domain )
 	                shift
 	                DOMAIN_NAME=$1
 	                ;;
 	        -u | --user* )
 	                shift
 	                USER_NAME=$1
 	                ;;
 	        -p | --pass* )
 	                shift
 	                PASSWORD=$1
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



cur_dir=$(pwd)

yukle()
{
	arch=`uname -i`
	echo "Detected architecture is $arch"
	RELEASE=`awk '{ print $3 }' < /etc/redhat-release`
	MAJOR=`echo $RELEASE | awk -F. '{ print $1 }'`
	MINOR=`echo $RELEASE | awk -F. '{ print $2 }'`
	echo "Detected CentOS Release: $RELEASE, Major=$MAJOR, Minor=$MINOR"


	repoFileName="/etc/yum.repos.d/CentOS-Base.repo"
	if [ ! -r $repoFileName -o ! -w $repoFileName ]; then
	 echo "Repository file $repoFileName is not readable or writtable!"
	 exit 1
	fi
	echo "Installing yum-priorities plugin..."
	yum -y install yum-priorities wget perl
	condition=`grep priority $repoFileName`
	if [ -z "$condition" ]; then
	 sed -i.back -e 's/\[base\]/\[base\]\npriority=1/' -e 's/\[addons\]/\[addons\]\npriority=1/' -e 's/\[updates\]/\[updates\]\npriority=1/' -e 's/\[extras\]/\[extras\]\npriority=1/' -e  's/\[centosplus\]/\[centosplus\]\npriority=2/' -e 's/\[contrib\]/\[contrib\]\npriority=2/' $repoFileName
	 echo "Repository file edited ok"
	else
	 echo "Priorities for base packages already set!"
	fi

	echo "Loading RPMForge RPM..."
	wget "http://apt.sw.be/redhat/el$MAJOR/en/$arch/rpmforge/RPMS/rpmforge-release-$repoVer.el$MAJOR.rf.$arch.rpm" || exit_with_message "RPMForge RPM download failed!"

	echo "Importing RPM Forge GPG key..."
	rpm --import http://dag.wieers.com/rpm/packages/RPM-GPG-KEY.dag.txt || exit_with_message "RPMForge GPG key download failed!"

	echo "Verifying RPMForge RPM..."
	rpm -K rpmforge-release-$repoVer.el$MAJOR.rf.*.rpm || exit_with_message "RPMForge GPG key verification failed!"

	echo "Installing RPMForge RPM..."
	rpm -Uvh rpmforge-release-$repoVer.el$MAJOR.rf.*.rpm || exit_with_message "RPMForge RPM installation failed!"

	echo "Editing RPMForge repo file..."
	repoFileName="/etc/yum.repos.d/rpmforge.repo"
	if [ ! -r $repoFileName -o ! -w $repoFileName ]; then
	 "Repository file $repoFileName is not readable or writtable!"
	 exit 1
	fi
	condition=`grep priority $repoFileName`
	if [ -z "$condition" ]; then
	 sed -i.back 's/\[rpmforge\]/\[rpmforge\]\npriority=20/' $repoFileName
	else
	 echo "Priorities for rpmforge packages already set!"
	fi
	rm -f rpmforge-release-$repo_ver.el$MAJOR.rf.$arch.rpm
	echo "Done!"



	# Disable IPv6.
	echo "alias net-pf-10 off" >> /etc/modprobe.conf
	echo "alias ipv6 off" >> /etc/modprobe.conf

	# Disable SElinux.
	sed -i 's/SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux
	/usr/sbin/setenforce 0

	yum -y install yum-fastestmirror wget


	# Set system time.
	yum install ntp -y
	\cp -f /usr/share/zoneinfo/Europe/Istanbul /etc/localtime
	/usr/sbin/ntpdate -v -b in.pool.ntp.org
	hwclock -w
	/bin/date

	yum install -y httpd mysql-server phpmyadmin vsftpd php-gd php
}

setRootPass()
{
	/usr/bin/mysqladmin --user=root password $1 1> /dev/null 2> /dev/null
	echo "UPDATE mysql.user SET password=PASSWORD('${1}') WHERE user='root';"> mysql.temp;
	echo "UPDATE mysql.user SET password=PASSWORD('${1}') WHERE password='';">> mysql.temp;
	echo "DROP DATABASE IF EXISTS test;" >> mysql.temp
	echo "FLUSH PRIVILEGES;" >> mysql.temp;
	/usr/bin/mysql mysql --user=root --password=${1} < mysql.temp;
	rm -f mysql.temp;
}

yukle


#echo $DOMAIN_NAME, $USER_NAME, $PASSWORD
isUserExits(){
    grep $1 /etc/passwd > /dev/null
    [ $? -eq 0 ] && return $TRUE || return $FALSE
}

createNewUser(){
		echo $@
    /usr/sbin/useradd "$@"
}

if ( ! isUserExits $USER_NAME )
    then
        createNewUser -m -s $USRSHELL $USER_NAME
         echo $PASSWORD | /usr/bin/passwd --stdin $USER_NAME
         chmod 755 /home/$USER_NAME
    else
        echo "Username \"$USER_NAME\" exists in /etc/passwd"
        exit 3
fi

cd /home/$USER_NAME
mkdir public_html
echo "<?php phpInfo(); ?>" > public_html/index.php
chown $USER_NAME:$USER_NAME public_html
chown $USER_NAME:$USER_NAME public_html/index.php
mkdir logs
cd logs
touch php_error.log error.log $DOMAIN_NAME.log
chown apache:apache php_error.log
chown $USER_NAME:$USER_NAME error.log $DOMAIN_NAME.log

CONF=/etc/httpd/conf.d/z_$USER_NAME.conf
touch $CONF

#get IP
IP=`ip addr |grep 'inet ' | grep -v '127.0.0.1' | awk '{ print $2}' | cut -d/ -f1`

cat > "$CONF" <<EOF
NameVirtualHost $IP:80

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

        php_admin_value open_basedir /home/$USER_NAME:/tmp:/usr/lib64/php/modules:/usr/share/phpmyadmin/
        php_admin_value error_log  /home/$USER_NAME/logs/php_error.log

</VirtualHost>
EOF

sed -i 's/  Allow from.*/  Allow from all/' /etc/httpd/conf.d/phpmyadmin.conf
sed -i "s/.*blowfish_secret.*/\$cfg[\'blowfish_secret\'] = \'$RANDOM\';/" /usr/share/phpmyadmin/config.inc.php

chkconfig httpd on
chkconfig mysqld on
chkconfig vsftpd on

service httpd start
service mysqld start
echo "Setting up MySQL Root Password...";
setRootPass $PASSWORD;

# create .my.cnf
echo "[client]" > /root/.my.cnf
echo "user=root" >> /root/.my.cnf
echo "password=$PASSWORD" >> /root/.my.cnf

service mysqld restart
service vsftpd start


