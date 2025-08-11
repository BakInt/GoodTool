#!/bin/bash

# 检查是否为 root 用户
if [ "$(id -u)" -ne 0 ]; then
    echo "此脚本需要以 root 权限运行。"
    exit 1
fi

# 自动检测 shutdown 路径
SHUTDOWN_CMD=$(which shutdown 2>/dev/null)
if [ -z "$SHUTDOWN_CMD" ]; then
    echo "未找到 shutdown 命令，请检查系统。"
    exit 1
fi

# 设置关机时间
set_shutdown_timer() {
    echo "请输入关机时间（格式 HH:MM），或输入 q 返回菜单。"
    read -p "关机时间: " shutdown_time

    # 输入 q 退出
    if [[ "$shutdown_time" == "q" || "$shutdown_time" == "Q" ]]; then
        echo "已取消设置关机时间，返回菜单。"
        return
    fi

    # 正则验证时间
    if [[ ! $shutdown_time =~ ^([01]?[0-9]|2[0-3]):([0-5][0-9])$ ]]; then
        echo "输入格式错误，请输入 00:00 到 23:59 之间的时间。"
        return
    fi

    hour=$(echo "$shutdown_time" | cut -d: -f1)
    minute=$(echo "$shutdown_time" | cut -d: -f2)

    # 添加定时任务到 root crontab
    (crontab -l 2>/dev/null; echo "$minute $hour * * * $SHUTDOWN_CMD -h now") | crontab -

    echo "已设置定时关机时间为 $shutdown_time。"
}

# 取消关机
cancel_shutdown_timer() {
    crontab -l 2>/dev/null | grep -v "$SHUTDOWN_CMD -h now" | crontab -
    echo "已取消所有定时关机任务。"
}

# 查看当前设置
view_shutdown_timer() {
    echo "当前的定时关机任务:"
    crontab -l 2>/dev/null | grep "$SHUTDOWN_CMD -h now" || echo "无定时关机任务。"
}

# 主菜单
while true; do
    echo "=============================="
    echo " 定时关机脚本"
    echo " 1. 设置定时关机"
    echo " 2. 取消定时关机"
    echo " 3. 查看定时关机"
    echo " q. 退出"
    echo "=============================="

    read -p "请输入选项: " choice

    case "$choice" in
        1) set_shutdown_timer ;;
        2) cancel_shutdown_timer ;;
        3) view_shutdown_timer ;;
        q|Q) echo "已退出程序。"; exit 0 ;;
        *) echo "无效选项，请重新输入。" ;;
    esac
done
