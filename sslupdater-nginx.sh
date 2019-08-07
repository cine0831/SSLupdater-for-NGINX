#!/bin/bash
# -*-Shell-script-*-
#
#/**
# * Title    : Automatic SSL certificate updater for NGINX"
# * Auther   : Alex, Lee
# * Created  : 09-12-2018
# * Modified : 11-15-2018
# * E-mail   : cine0831@gmail.com
#**/
#
#set -e
#set -x

# 기본설정
_DATE=$(date +%Y%m%d)
_TIME=$(date +%F_%X)
_HOME="/usr/mgmt/SSL_checker"
_LOGDIR="$_HOME/logs"
_RESULT="$_LOGDIR/updater_${_DATE}.log"
_DOWN="$_HOME/down"
_STORAGE="ims.powdersnow.co.kr"
_REPO="http://${_STORAGE}/ssl_key/files"

# new 인증서 저장 디렉토리
if [ ! -d $_DOWN ]; then
    mkdir -p $_DOWN
fi

# 기본 로그 파일 설정
if [ ! -d $_LOGDIR ]; then
    mkdir -p $_LOGDIR
fi

#if [ ! -f $_RESULT ]; then
#    touch $_RESULT
#else 
#    cat /dev/null > $_RESULT
#fi

# 로깅
function _loging() {
    local OUTPUT=$1
    if [ ! -z "$OUTPUT" ]; then
        echo -e "$_TIME :\n $OUTPUT" | tee -a $_RESULT > /dev/null 2>&1 
    fi
    echo -e "------------------------------------------------------------------------------------------------------------------------------" | tee -a $_RESULT > /dev/null 2>&1 
}

# 인증서 파일 변경
function _changeSSL() {
    local _source=$1
    local _target=$2
    local _change=$3

    echo "$_TIME : $_change " | tee -a $_RESULT > /dev/null 2>&1
    cp -pfv $_source $_target | tee -a $_RESULT > /dev/null 2>&1 
    _loging ""
}

# SSL 인증서 다운로드
function _down() {
    result=""

    local empty=""
    local sslfile=$1
    curl -X GET -s $_REPO/$sslfile --output $_DOWN/$sslfile
    retval=$?
    if [ ! $retval -eq 0 ]; then
        _loging "failed download for new SSL file"
        continue
    fi

    # 신규인증서 무결성 확인
    openssl x509 -in $_DOWN/$sslfile -noout
    retval=$?
    if [ $retval -eq 0 ]; then
        result="true"
    else
        result="false"
    fi
}

# SSL 인증서 최신파일과 현재파일 md5 비교
function _md5() {
    result=""

    # PHP 실행파일의 path 정의
    # 인증서 만료날짜를 가져오는 expire_date_output.php 에서 필요
    local php_1="/home/php/bin/php"
    local php_2="/home/apps/php/bin/php"
    local php_3="/usr/local/php/bin/php"
    local php_4="/usr/local/bin/php"

    if [ -f $php_1 ]; then
        local _php=$php_1
    elif [ -f $php_2 ]; then
        local _php=$php_2
    elif [ -f $php_3 ]; then
        local _php=$php_3
    elif [ -f $php_4 ]; then
        local _php=$php_4
    else
        local _php=$(which php 2>/dev/null)
    fi

    # 인증서의 md5 value
    local md5_new=$(md5sum $_HOME/down/$1 | awk '{print $1}')
    local md5_current=$(md5sum $2 | awk '{print $1}')

    # 인증서의 만료 날짜 그러나 PHP 설치되어 있지 않으면 skip
    if [ $_php ]; then
        local date_new=$($_php $_HOME/expire_date_output.php $_HOME/down/$1)
        local date_current=$($_php $_HOME/expire_date_output.php $2)
    else
        _loging "skip compare expire date because php is not installed"
        #echo -e "skip compare expire date because php is not installed"
    fi

    # 신규 인증서와 사용중인 인증서의 md5 그리고 만료 날짜 확인
    if [ ${md5_new} = ${md5_current} ] && [ ${date_new} = ${date_current} ]; then
        _loging "\"$1\" SSL certification due date is not expired currently"
        result="true"
        continue
    else
        result="false"
    fi
}

# NGINX 테스트 및 reload
function _nginx {
    result=""

    local nginx="$1/sbin/nginx"
    local status=$2
    local option="$3"

    # configtest
    if [ $status -eq 0 ]; then
        echo "$_TIME : configtest" | tee -a $_RESULT > /dev/null 2>&1
        $nginx $option 2>&1 | tee -a $_RESULT
        retval=$?
        if [ $retval -ne 0 ]; then
            result="false"
        else
            result="true"
        fi
        _loging ""
    fi

    # reload
    if [ $status -eq 1 ]; then
        $nginx $option 2>&1 | tee -a $_RESULT
        result="true"
        _loging "nginx: daemon reload is successful"
        echo -e "nginx: daemon reload is successful"
    fi
}

# MAIN
function _run() {
    # NGINX 프로세스 구동중인지 확인
    _nginx_ps=$(ps aux | grep nginx | grep 'master process' | egrep -v 'nobody|grep|bash|log|py' | grep root)
    retval=$?
    if [ $retval -eq 0 ]; then
        _nginx_status=1
    else
        _nginx_status=0
    fi

    for ((i = 2; i <= $#; i++))
    do
        # nginx home directory
        eval "nginx=\${$i}"

        # nginx config directory
        eval "arg=\${$i}/conf"

        # nginx 디렉토리안에 nginx.conf 파일이 있는지 비교
        if [ -d $arg ] && [ -f $arg/nginx.conf ]
        then
            _list_=$(grep -i 'ssl_certificate' ${arg}/*.conf | grep "\.crt" | grep -v '#' | awk '{print $3}' | sed -e 's/;//g' -e 's/\// /g' | awk 'NF>1{print $NF}' | sort -u)

            for j in $_list_
            do
                # Let's encrypt 인증서는 진행하지 않음
                #if [ "$j" != "default_server.crt" ] || [ "$j" != "default_server.key" ]; then
                if [ "$j" = "default_server.crt" ]; then
                    continue
                else
                    # 신규 인증서 다운로드
                    _down $j

                    # 다운로드 받은 신규 인증서의 무결성 검사 실패시 해당 파일은 업데이트 하지 않음
                    if [ "false" = $result ]; then
                        _loging "$j file is not update target"
                        continue
                    else
                        # conf/ssl 디렉토리 부분 (주로 웹호스팅 상품에서 사용)
                        if [ -d $arg/ssl ] && [ -f $arg/ssl/$j ]; then
                            _md5 "$j" "$arg/ssl/$j"
                            if [ "false" = $result ]; then
                                # update SSL files
                                _changeSSL "$arg/ssl/$j" "$arg/ssl/$j.bak.sm_${_DATE}" "change"
                                _changeSSL "$_HOME/down/$j" "$arg/ssl/$j" "change"

                                # NGINX configtest
                                _nginx $nginx "0" "-t"

                                # configtest 실패시 인증서 파일 롤백
                                if [ "false" = $result ]; then
                                    _changeSSL "$arg/ssl/$j.bak.sm_${_DATE}" "$arg/ssl/$j" "rollback"
                                fi
                            fi
                        fi

                        # conf/ssl_key 디렉토리 부분 (TPL, EC, BUILDER 등의 대부분의 서버에서 사용)
                        if [ -d $arg/ssl_key ] && [ -f $arg/ssl_key/$j ]; then
                            _md5 "$j" "$arg/ssl_key/$j"
                            if [ "false" = $result ]; then
                                # update SSL files
                                _changeSSL "$arg/ssl_key/$j" "$arg/ssl_key/$j.bak.sm_${_DATE}" "change"
                                _changeSSL "$_HOME/down/$j" "$arg/ssl_key/$j" "change"

                                # NGINX configtest
                                _nginx $nginx "0" "-t"

                                # configtest 실패시 인증서 파일 롤백
                                if [ "false" = $result ]; then
                                    _changeSSL "$arg/ssl_key/$j.bak.sm_${_DATE}" "$arg/ssl_key/$j" "rollback"
                                fi
                            fi
                        fi
                    fi
                fi
            done
        else
            _loging "nginx is not installed in $nginx"
            #echo -e "nginx is not installed in $nginx"
            nginx_status=0
            continue
        fi

        # NGINX daemon reload
        if [ -f $nginx/sbin/nginx ] && [ $_nginx_status -eq 1 ]; then 
            _nginx $nginx $_nginx_status "-s reload"
        else
            _loging "nginx: daemon has not been reloaded because not running"
            echo -e "nginx: daemon has not been reloaded because not running"
        fi
    done
}

while getopts ":d" opt; do
    case $opt in
        d)
            # call _run
            _run "$@"
            ;;
        \?)
            echo "Usage: cmd [-d] directories" >&2
            ;;
    esac
done
