#! /usr/bin/env bash

alias gh='HTTPS_PROXY=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 gh'

# systemctl 简写
alias sc='sudo systemctl'
alias scu='systemctl --user'
alias scs='systemctl status'
alias scus='systemctl --user status'
alias scr='sudo systemctl restart'
alias scur='systemctl --user restart'

# journalctl 简写
alias jc='journalctl'
alias jcu='journalctl --user'
alias jcf='journalctl -f'
alias jcuf='journalctl --user -f'
alias jcb='journalctl -b'
alias jce='journalctl -e'

# 让简写继承 systemctl / journalctl 的自动补全
if type _completion_loader &>/dev/null; then
    _completion_loader systemctl
    _completion_loader journalctl
fi
if declare -F _systemctl &>/dev/null; then
    complete -F _systemctl sc scs scr
    _systemctl_user() {
        COMP_WORDS=(systemctl --user "${COMP_WORDS[@]:1}")
        (( COMP_CWORD += 1 ))
        _systemctl
    }
    complete -F _systemctl_user scu scus scur
fi
if declare -F _journalctl &>/dev/null; then
    complete -F _journalctl jc jcf jcb jce
    _journalctl_user() {
        COMP_WORDS=(journalctl --user "${COMP_WORDS[@]:1}")
        (( COMP_CWORD += 1 ))
        _journalctl
    }
    complete -F _journalctl_user jcu jcuf
fi

# 设置代理变量
proxy() {
    case "$1" in
        on)
            local port="${2:-7890}"
            export all_proxy="http://127.0.0.1:${port}"
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
            echo "usage: proxy {on [port]|off|status}" >&2
            return 1
            ;;
    esac
}
