#! /usr/bin/env bash

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
