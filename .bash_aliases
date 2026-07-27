#! /usr/bin/env bash

alias gh='HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 gh'

# 设置代理变量
proxy() {
    case "$1" in
        on)
            export all_proxy="http://127.0.0.1:7890"
            export ALL_PROXY="$all_proxy"

            for v in http https ftp; do
                export ${v}_proxy="$all_proxy"
                export ${v^^}_PROXY="$all_proxy"
            done

            export no_proxy="localhost,127.0.0.1,::1"
            export NO_PROXY="$no_proxy"
            ;;
        off)
            unset all_proxy http_proxy https_proxy ftp_proxy all_proxy no_proxy \
                ALL_PROXY HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY NO_PROXY
            ;;
        status)
            env | grep -i '_proxy'
            ;;
        *)
            echo "usage: proxy {on|off|status}" >&2
            return 1
            ;;
    esac
}

# 导出MySQL数据库结构
mysqldump_structure() {
    mysqldump --no-create-db --no-data --events --routines --compact "$@" \
    | sed -E 's/^\/\*![0-9]+.*\*\/;?\s*//g' \
    | sed -E 's/ AUTO_INCREMENT=[0-9]+//g' \
    | tr --squeeze-repeats '\n' \
    | sed -E '/^CREATE TABLE/i\\'
}