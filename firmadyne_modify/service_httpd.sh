#!/bin/sh
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/sbin/tr069
source /etc/init.d/ulog_functions.sh
source /etc/init.d/event_handler_functions.sh
source /etc/init.d/service_httpd/httpd_functions.sh
SERVICE_NAME="httpd"
SELF_NAME="`basename $0`"
SELF_HOME="$(dirname $(readlink -f $0))"
SELF_BIN=$SELF_HOME/service_httpd
BLOCK=$SELF_BIN/block-interfaces
PASSWORD_FILE=/tmp/.htpasswd
PMON=/etc/init.d/pmon.sh
append_lighttpd_common_conf() {
   CONF_FILE=$1
   model="`syscfg get device::model_base`"
   if [ -z $model ] ; then
       model="`syscfg get device::modelNumber`"
   fi
   if [ -z $model ] ; then   
       echo "WARN: Model base was empty"
   else 
       echo "Lighttpd Model Base: "$model
   fi
   
    if [ -f $SELF_BIN/lighttpd-rainier-conf.lua ]; then
        echo "Generating Rainier lighttpd config"
        lua $SELF_BIN/lighttpd-rainier-conf.lua > /tmp/lighttpd.conf
    else
            echo "Initializing WebUI 1.0"
            if [ -e /etc/lighttpd.conf ]; then
                IPADDR=$(ifconfig br0 | grep -o "inet addr:[0-9\.]*" | grep -o "\([0-9]\{1,3\}\.\)\{3\}" | sed 's/\./\\\\\./g')
                EXPRESS="s/IPLOCAL/"$IPADDR"/g"
                cat /etc/init.d/service_httpd/lighttpd.conf | sed $EXPRESS > /tmp/lighttpd-tmp
                if [ -e /www/HNAP1/index.* ]; then
                    cat /tmp/lighttpd-tmp | sed 's/HNAP_REGEX/\|HNAP/g' > /tmp/lighttpd-tmp2	
                    rm -f /tmp/lighttpd-tmp
                fi
                MODEL_BASE="s/#MODEL_BASE#/"$model"/g"
                cat /tmp/lighttpd-tmp2 | sed $MODEL_BASE > /tmp/lighttpd.conf
                rm -f /tmp/lighttpd-tmp2
            fi
    fi
}
append_lighttpd_setupldal_conf() {
   CONF_FILE=$1
   cat $SELF_HOME/service_setupldal/lighttpd_setupldal_conf >> $CONF_FILE
}
append_lighttpd_lsdp_conf() {
   CONF_FILE=$1
   cat $SELF_HOME/service_lsdp/lighttpd_lsdp_conf >> $CONF_FILE
}
define_lighttpd_env() {
   CONF_FILE=/etc/lighttpd.conf
   PID_FILE=/var/run/lighttpd.pid
   BIN=lighttpd
}
prepare_lighttpd() {
   define_lighttpd_env
   echo "" > $CONF_FILE
   append_lighttpd_common_conf $CONF_FILE
   if [ -f /www/lsdp/index.fcgi ]; then
   	append_lighttpd_lsdp_conf $CONF_FILE
   fi
   if [ -f /www/association/association.fcgi ]; then
   	append_lighttpd_setupldal_conf $CONF_FILE
   fi
	CONFIGDIR="/tmp/var/config"
	LICENSEDIR="${CONFIGDIR}/license"
	OLDLICENSEDIR="${CONFIGDIR}/licenses"
	BOOTPART=`syscfg get fwup_boot_part`
	DEFAULTLICENSE="FW_LICENSE_default.pdf.gz"
	
	if [ -e "${OLDLICENSEDIR}" ]; then
		rm -rf ${OLDLICENSEDIR}
	fi
	if [ ! -e "${LICENSEDIR}" ]; then
		echo "Creating ${LICENSEDIR}"
		mkdir -p ${LICENSEDIR}
	fi
	if [ -e "${LICENSEDIR}/primary" ]; then
		PRIMARYLICENSE=`cat ${LICENSEDIR}/primary`
	else
		PRIMARYLICENSE=
	fi
	if [ -e "${LICENSEDIR}/alternate" ]; then
		ALTERNATELICENSE=`cat ${LICENSEDIR}/alternate`
	else
		ALTERNATELICENSE=
	fi
	syscfg unset license_url
	if [ "${BOOTPART}" = "1" ]
	then
		if [ -z ${PRIMARYLICENSE} ]
	    then
			cp /etc/${DEFAULTLICENSE} ${LICENSEDIR}/fw_license.pdf.gz
	    elif [ -e "${LICENSEDIR}/${PRIMARYLICENSE}.gz" ]
	    then
			syscfg set license_url ${PRIMARYLICENSE}.gz
	    fi
	else
		if [ -z ${ALTERNATELICENSE} ]
		then
			cp /etc/${DEFAULTLICENSE} ${LICENSEDIR}/fw_license.pdf.gz
		elif [ -e "${LICENSEDIR}/${ALTERNATELICENSE}.gz" ]
		then
			syscfg set license_url ${ALTERNATELICENSE}.gz
		fi
	fi
   wwwconf="`syscfg get www_conf_dir`";
   if [ ! -z wwwconf ]; then 
   	echo "Build temporary www configuration directory: "$wwwconf
	if [ ! -e $wwwconf ]; then
		mkdir -p $wwwconf
		ln -s $wwwconf /www/conf
   	fi
   fi
}
check_esm_server() {
    pgrep -x $BIN  > /dev/null 2>&1
}
do_status_lighttpd() {
    define_lighttpd_env
    check_esm_server
}
do_start_lighttpd() {
   sysevent set ${SERVICE_NAME}-errinfo
   sysevent set ${SERVICE_NAME}-status starting
   mkdir -p /var/config/esm
   mkdir -p /var/config/events
   mkdir -p /var/config/ewps
   ldal_passphrase=`echo $SYSCFG_ldal_wl_passphrase | sed -e 's/\///g'`
   define_lighttpd_env
   gen_authfile "$SYSCFG_http_admin_user" "$SYSCFG_http_admin_password" "encoded"
   gen_authfile "ldal" "$ldal_passphrase" "cleartext"
   ulog httpd status "Blocking non-lan access to ports $($BLOCK list)"
   $BLOCK start
   logger -t ESM $(printf \
       "Registering for firewall-status changes returns %s"  \
       "$(sysevent async firewall-status $SELF_BIN/firewall-change-handler)" \
   )
   $BIN -f $CONF_FILE
   REGISTER_SERVICES="$SELF_BIN/register_services"
   sleep 10
   local RETRY_DELAY=5
   if [ "$SYSCFG_lego_enabled" != "0" ]; then
       until check_esm_server && $REGISTER_SERVICES; do
	   if ! check_esm_server; then
	       logger -t ESM "Error: ESM Web server not running"
	       echo "ESM HTTP Server not running; CHE services will not be available"
	       break
	   fi
	   result=$?
	   logger -t ESM "ESDD service registration failed with error code $result"
	   logger -t ESM "Will retry in $RETRY_DELAY seconds" 
	   sleep $RETRY_DELAY
       done
       logger -t ESM "ESDD service registration succeeded"
       logger -t ESM $(printf \
	   "ESDD reregistration for IPv4 address change returns %s" \
	   "$(sysevent async ipv4_wan_ipaddr $REGISTER_SERVICES)"   \
	   )
   fi
}
do_stop_lighttpd() {
   define_lighttpd_env
   killall $BIN
   rm -f $PID_FILE $PASSWORD_FILE
   ulog httpd status "Restoring non-lan access to ports $($BLOCK list)"
   $BLOCK stop
}
prepare_minihttpd() {
   CONF_FILE=/etc/mini_httpd.conf
   PID_FILE=/var/run/mini_httpd.pid
   LOG_FILE=/var/log/mini_httpd.log
   BIN=mini_httpd
}
do_start_minihttpd() {
   gen_authfile "$SYSCFG_http_admin_user" "$SYSCFG_http_admin_password" "encoded"
   PORT=$SYSCFG_http_admin_port
   if [ "" = "$PORT" ] ; then
      PORT=80
   fi
   echo "nochroot" >> $CONF_FILE
   echo "port=$PORT" >> $CONF_FILE
   echo "dir=/www" >> $CONF_FILE
   echo "data_dir=/www" >> $CONF_FILE
   echo "user=root" >> $CONF_FILE
   echo "logfile=$LOG_FILE" >> $CONF_FILE
   echo "pidfile=$PID_FILE" >> $CONF_FILE
   echo "cgipat=cgi-bin/*|**.cgi" >> $CONF_FILE
   $BIN -C $CONF_FILE
}
do_stop_minihttpd() {
   kill -9 `cat $PID_FILE`
   rm -f $PID_FILE
   rm -f $CONF_FILE $PASSWORD_FILE
}
is_lighttpd_running() {
    retVal=0
    if [ ! -f "$PID_FILE" ]; then 
	retVal=1 # Stopped
    elif [ "$(cat $PID_FILE)" == "$(pgrep lighttpd)" ]; then
	retVal=0 # Running
    else
	retVal=1 # Stopped
    fi
    return $retVal
}
is_device_ready() {
    retVal=0
    LAN_STATUS=`sysevent get lan-status`
    if [ "started" == "$LAN_STATUS" ] ; then
        retVal=0
    else
        retVal=1
    fi
    return $retVal
}
service_init ()
{
    eval `utctx_cmd get http_admin_user http_admin_port http_admin_password mgmt_http_enable mgmt_https_enable mgmt_wan_access  mgmt_wan_httpaccess mgmt_wan_httpsaccess mgmt_wan_httpport mgmt_wan_httpsport ldal_wl_passphrase lego_enabled dot_local_domain dot_local_hostname`
}
service_start ()
{
    wait_till_end_state ${SERVICE_NAME}
    STATUS=`sysevent get ${SERVICE_NAME}-status`
    if [ "started" != "$STATUS" ] ; then
	ulog ${SERVICE_NAME} status "starting ${SERVICE_NAME} service" 
	if ! is_lighttpd_running ; then
            prepare_lighttpd
            do_start_lighttpd
	fi
	mkdir -p /var/config/esm
	mkdir -p /var/config/events
	mkdir -p /var/config/ewps
	$PMON setproc httpd $BIN $PID_FILE "/etc/init.d/service_httpd.sh httpd-restart"
	if is_lighttpd_running ; then
            sysevent set ${SERVICE_NAME}-errinfo
            sysevent set ${SERVICE_NAME}-status "started"
	else
            sysevent set ${SERVICE_NAME}-status "error"
            sysevent set ${SERVICE_NAME}-errinfo "failed to start"
	fi
    wait_till_end_state nfqrecv
    CNT=0
    MAXWAIT=10
    while [ $CNT -lt $MAXWAIT ] 
    do
        if is_device_ready ; then
            echo "Restarting nfqrecv service..." > /dev/console
            sysevent set nfqrecv-restart
            break
        else
            echo "Device IS NOT Ready..." > /dev/console
        fi
        sleep 1
        CNT=`expr $CNT + 1`
    done
    fi
}
service_stop ()
{
    wait_till_end_state ${SERVICE_NAME}
    sysevent set ${SERVICE_NAME}-errinfo
    sysevent set ${SERVICE_NAME}-status stopping
    STATUS=`sysevent get ${SERVICE_NAME}-status` 
    if [ "stopped" != "$STATUS" ] ; then
	ulog ${SERVICE_NAME} status "stopping ${SERVICE_NAME} service" 
	define_lighttpd_env
	if [ -f "$PID_FILE" ] ; then
            do_stop_lighttpd
	fi
	$PMON unsetproc httpd
	sysevent set ${SERVICE_NAME}-errinfo
	sysevent set ${SERVICE_NAME}-status "stopped"
    fi
}
service_restart () 
{
     service_stop
     service_start
}

/bin/busybox basename aaa
service_init
case "$1" in
  ${SERVICE_NAME}-start)
      service_start
      ;;
  ${SERVICE_NAME}-stop)
      service_stop
      ;;
  ${SERVICE_NAME}-restart)
      service_restart
      ;;
  
  ${SERVICE_NAME}-status)
      do_status_lighttpd
      ;;
  lan-started)
      ulog ${SERVICE_NAME} status "${SERVICE_NAME} service, triggered by $1"
      service_restart
      ;;
  lan-stopping)
      ulog ${SERVICE_NAME} status "${SERVICE_NAME} service, triggered by $1"
      service_stop
      ;;
  *)
        echo "Usage: $SELF_NAME [${SERVICE_NAME}-start|${SERVICE_NAME}-stop|${SERVICE_NAME}-status|${SERVICE_NAME}-restart|lan-started|generate_authfile|generate_passwd]" >&2
        exit 3
        ;;
esac
