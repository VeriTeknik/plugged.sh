#!/bin/bash
###############################################################################
#     Copyright Plugged.in 2012-2015 All rights reserved
###############################################################################
# This scirpt installs everything needed to run a web server and 
# updates, installs & configures various options of a clearly installed system
# 
#
# Version 1.0 for CentOS 7.X
# USE AT YOUR OWN RISK!!!
# type the following:
#
# chmod 755 plugged.sh
#
# after this has been done, you can type ./plugged.sh to run the script.
#     
# 
###############################################################################

#cnt1=55
#noktalar=$(printf '%0.s-' $(seq 1 $cnt1))
#      echo $noktalar


LogOutput="/usr/local/Plugged/logs"
WorkDir="/usr/local/Plugged"
LOG_FILE="${WorkDir}/${CUR_NAM}.log.`date +%Y%m%d%H%M`"
CUR_NAM=`basename $0`

DOMAIN_NAME=
USER_NAME=
PASSWORD=
IP=
CONF=

# LIB



# END LIB

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install lnmp"
    exit 1
fi


read_choice ()
{
    local pr="$1"
    [ -z "$pr" ] && pr="`hostname`> Type your choice or 'x' for exit: "

    read -e -p "$pr" result
    echo -n "$result"
    return 0
}

header()
{
	echo "        _                            _       _     "
	echo "       | |                          | |     | |    "
	echo "  _ __ | |_   _  __ _  __ _  ___  __| |  ___| |__  "
	echo " |  _ \| | | | |/ _  |/ _  |/ _ \/ _  | / __|  _ \ "
	echo " | |_) | | |_| | (_| | (_| |  __/ (_| |_\__ \ | | |"
	echo " | .__/|_|\__,_|\__, |\__, |\___|\__,_(_)___/_| |_|"
	echo " | |             __/ | __/ |                       "
	echo " |_|            |___/ |___/                        "
	echo "----------------------------------------------------------------------"
	echo "																									 "
}


main_menu ( )
{
	LASTMENU="main_menu"
  clear
	header
	echo ">>::HOME															 	       "
	echo "																									 "
	echo "																									 "
	echo " _____ ___ ___ _ _ "
	echo "|     | -_|   | | |"
	echo "|_|_|_|___|_|_|___|"
	echo "                  				"
	echo "-------------------------------|--------------------------------------"
	echo "                               |										 "
	echo "1-Firewall                     | 2-Add Domain							 "
	echo "                               |										 "
	echo "----------------------------------------------------------------------"
	read -n 1 -p "Type q to Exit, x to Go Back:" Command
	case $Command in
	x)
		exit 1
		;;
	q)
		exit 1
		;;
	1)
		firewall_menu
		;;
	esac
	#CHOICE=`read_choice "$PROMPT"`
}

IsFirewallEnabled()
{
	RESULT=`systemctl list-unit-files | grep -i 'firewalld.service' | awk '{print $2}'`
	case $RESULT in
		enabled)
		retval=`echo -e "\e[92m[ENABLED]\e[0m"`
		;;
		disabled)
		retval=`echo -e "\e[91m[DISABLED]\e[0m"`
		;;
	esac
	echo $retval
}

toggle_firewall_service()
{
	RESULT=`systemctl list-unit-files | grep -i 'firewalld.service' | awk '{print $2}'`
	case $RESULT in
		enabled)
		RES=`systemctl disable firewalld.service &> /dev/null`
		;;
		disabled)
		RES=`systemctl enable firewalld.service &> /dev/null`
		;;
	esac
}

IsFirewallRunning()
{
	RESULT=`systemctl status firewalld.service | grep -i "Active:" | awk '{print $2}'`
	case $RESULT in
		active)
		retval=`echo -e "\e[92m[RUNNING]\e[0m"`
		;;
		inactive)
		retval=`echo -e "\e[91m[INACTIVE]\e[0m"`
		;;
	esac
	echo $retval
}

toggle_firewall_run()
{
	RESULT=`systemctl status firewalld.service | grep -i "Active:" | awk '{print $2}'`
	case $RESULT in
		active)
		RES=`systemctl stop firewalld.service &> /dev/null`
		;;
		inactive)
		RES=`systemctl start firewalld.service &> /dev/null`
		;;
	esac
}


firewall_menu( )
{
	LASTMENU="firewall_menu"
  clear
	header
	echo "		>>::HOME::Firewall														 	       "
	echo "																									 "
	echo "																									 "
	echo "	Enabled Services: `firewall-cmd --zone=public --list-services`         						 "
	echo "	Enabled Ports   : `firewall-cmd --zone=public --list-ports`									"
	echo "																									 "
	echo " _____ ___ ___ _ _ "
	echo "|     | -_|   | | |"
	echo "|_|_|_|___|_|_|___|"
	echo "                  				"
	echo "-------------------------------|--------------------------------------"
	echo "1-Add/Remove Services          | 2-Add Ports       						   "
	echo "-------------------------------|--------------------------------------"
	echo "3-Start/Stop Firewall:         | Currently: $(IsFirewallRunning)"
	echo "4-Toogle Firewall on Boot:     | Currently: $(IsFirewallEnabled)"
	echo "----------------------------------------------------------------------"
	
	read -n 1 -p "Type q to Exit, x to Go Back:" Command
	case $Command in
	1)
		firewall_menu_AddService
		;;
	2)
		firewall_menu_AddPort
		;;
	3)
		toggle_firewall_run
		firewall_menu
		;;
	4)
		toggle_firewall_service
		firewall_menu
		;;
	x)
		main_menu
		;;
	q)
		exit 1
		;;
	1)
		firewall_menu
		;;
	esac
	#CHOICE=`read_choice "$PROMPT"`
}

firewall_list_services()
{
	val1=""
	ACTIVE_SERVICES=`firewall-cmd --zone=public --list-services`
	AVAILABLE_SERVICES=`firewall-cmd --get-services`
	cnt=0
	for i in $AVAILABLE_SERVICES
    do
      :
      val="$i "
      color1=""
      color2=""
      (( cnt++ ))
      for j in $ACTIVE_SERVICES
      do
      :
      if [ $i == $j ]
      then
      	color1="\e[92m-> "
      	color2="\e[0m"
      fi
      done

      cnt1=$((21-${#val}))
      noktalar=$(printf '%0.s ' $(seq 1 $cnt1))
      if [ -z $color1 ]; then 
      ((cnt%3==0)) && val1+="   $val \n"  || val1+="   $val$noktalar|"
      else
      ((cnt%3==0)) && val1+="$color1$val$color2\n"  || val1+="$color1$val$color2$noktalar|"
      fi
    done
    IFS='%'
	echo -e $val1
	IFS=' '
}

firewall_list_ports()
{
	val1=""
	ACTIVE_SERVICES=`firewall-cmd --zone=public --list-ports`
	cnt=0
	for i in $ACTIVE_SERVICES
    do
      :
      val="$i "
      (( cnt++ ))
      cnt1=$((21-${#val}))
      noktalar=$(printf '%0.s ' $(seq 1 $cnt1))
      ((cnt%3==0)) && val1+=" $val \n"  || val1+=" $val$noktalar|"
    done
    IFS='%'
	echo -e $val1
	IFS=' '
}


toggle_service()
{
	echo -e "\e[92m PLEASE WAIT \e[0m"
	AVAILABLE_SERVICES=`firewall-cmd --get-services`
	InServices=0
	for i in $AVAILABLE_SERVICES
	do
		if [ "$i" == "$1" ] ; then
	    	InServices=1
    fi
	done
	if [ $InServices == 0 ] ; then return 
	fi
	
	ACTIVE_SERVICES=`firewall-cmd --zone=public --list-services`
	Found=0
	for i in $ACTIVE_SERVICES
	do
		if [ "$i" == "$1" ] ; then
	    	Found=1
    fi
	done
	(($Found)) && RES=`firewall-cmd --zone=public --permanent --remove-service=$1 &> /dev/null` || RES=`firewall-cmd --zone=public --permanent --add-service=$1 &> /dev/null`
	RES=`firewall-cmd --reload &> /dev/null`
}

toggle_port()
{
	echo -e "\e[92m PLEASE WAIT \e[0m"
	
	ACTIVE_SERVICES=`firewall-cmd --zone=public --list-ports`
	Found=0
	for i in $ACTIVE_SERVICES
	do
		if [ "$i" == "$1" ] ; then
	    	Found=1
    fi
	done
	(($Found)) && RES=`firewall-cmd --zone=public --permanent --remove-port=$1 &> /dev/null` || RES=`firewall-cmd --zone=public --permanent --add-port=$1 &> /dev/null`
	RES=`firewall-cmd --reload &> /dev/null`
}

firewall_menu_AddService( )
{
	LASTMENU="firewall_menu_AddService"
  clear
	header
	echo "		>>::HOME::Firewall::Add/Remove Service										 	       "
	echo "																									 "
	echo "																									 "
	echo "------------------------|------------------------|--------------------"
	echo " Services: "
	echo "------------------------|------------------------|--------------------"
	echo "$(firewall_list_services)"
	echo "------------------------|------------------------|--------------------"
	echo "																									 "
	echo " _____ ___ ___ _ _ "
	echo "|     | -_|   | | |"
	echo "|_|_|_|___|_|_|___|"
	echo "                  				"
	echo "---------------------------------|------------------------------------"
	echo -e "	LEGEND: \e[92m-> ENABLED SERVICE \e[0m"
	echo "	Type q to Exit x to Go Back							 "
#	echo "	Type Service name to toggle (be carefull, enter will apply the rule):"


	read -p "	Type Service name to toggle (be carefull, ENTER will toogle the rule):" Command
	case $Command in
	x)
		firewall_menu
		;;
	q)
		exit 1
		;;
	*)
		toggle_service $Command
		;;
	esac
}

firewall_menu_AddPort( )
{
	LASTMENU="firewall_menu_AddPort"
  clear
	header
	echo "		>>::HOME::Firewall::Add/Remove Port										 	       "
	echo "																									 "
	echo "																									 "
	echo "----------------------|----------------------|------------------------"
	echo " Ports:                                                               "
	echo "----------------------|----------------------|------------------------"
	echo "$(firewall_list_ports)"
	echo "----------------------|----------------------|------------------------"
	echo "																									 "
	echo " _____ ___ ___ _ _ "
	echo "|     | -_|   | | |"
	echo "|_|_|_|___|_|_|___|"
	echo "                  				"
	echo "---------------------------------|------------------------------------"
	echo "	Type q to Exit, x to Go Back to previous Menu							 "
	echo "	Examples: 8800-8080/udp or 81/tcp"


	read -p "	Type Port number and protocol to toggle (eg: 8080/tcp):" Command
	case $Command in
	x)
		firewall_menu
		;;
	q)
		exit 1
		;;
	*)
		toggle_port $Command
		;;
	esac
}

#END
LASTMENU="main_menu"

while [ 1 ]; do
	eval ${LASTMENU}
done
