#!/bin/bash

# 检查是否是root用户
if [ "$(id -u)" != "0" ]; then
   echo "请使用sudo或以root用户运行此脚本" 
   exit 1
fi

# 菜单显示
show_menu() {
    clear
    echo "===== 定时关机控制程序 ====="
    echo "1. 设置定时关机"
    echo "2. 取消定时关机" 
    echo "3. 查看当前定时关机设置"
    echo "4. 退出"
    echo "============================"
    echo -n "请输入选择 [1-4]: "
}

# 设置定时关机
set_shutdown() {
    echo -n "请输入关机时间(格式HH:MM，如23:30): "
    read shutdown_time
    hour=$(echo $shutdown_time | cut -d: -f1)
    minute=$(echo $shutdown_time | cut -d: -f2)
    
    # 写入crontab
    (crontab -l 2>/dev/null | grep -v "/sbin/shutdown" ; echo "$minute $hour * * * /sbin/shutdown -h now") | crontab -
    echo "已设置每天 $shutdown_time 定时关机"
}

# 取消定时关机
cancel_shutdown() {
    crontab -l | grep -v "/sbin/shutdown" | crontab -
    echo "已取消定时关机任务"
}

# 查看当前设置
view_shutdown() {
    echo "当前定时关机设置:"
    crontab -l | grep "/sbin/shutdown" || echo "未设置定时关机"
}

# 主循环
while true; do
    show_menu
    read choice
    case $choice in
        1) set_shutdown ;;
        2) cancel_shutdown ;;
        3) view_shutdown ;;
        4) exit 0 ;;
        *) echo "无效输入，请重新选择" ;;
    esac
    echo "按回车键继续..."
    read
done
