#!/bin/bash

# 检查并安装 Docker
function check_install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker 未安装，开始安装..."
        curl -fsSL https://get.docker.com | sh
        if [ $? -ne 0 ]; then
            echo "Docker 安装失败"
            return 1
        fi
        systemctl start docker
        systemctl enable docker
        echo "Docker 安装完成"
    else
        echo "Docker 已安装"
    fi

    if ! command -v docker-compose &> /dev/null; then
        echo "Docker Compose 未安装，开始安装..."
        curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        if [ $? -ne 0 ]; then
            echo "Docker Compose 安装失败"
            return 1
        fi
        chmod +x /usr/local/bin/docker-compose
        echo "Docker Compose 安装完成"
    else
        echo "Docker Compose 已安装"
    fi
    return 0
}

REPO_DIR="/root/Gradient"
PROXIES_FILE="$REPO_DIR/proxies.txt"

# 函数：让用户输入代理信息并写入文件
function input_proxies() {
    echo "请输入代理信息，每行一个代理，格式为：[protocol]://[user]:[password]@[ip]:[port]"
    echo "例如：http://user:password@192.168.1.1:8080"
    echo "输入完成后，请输入一个空行来结束。"

    # 创建或清空文件
    > "$PROXIES_FILE"

    while true; do
        read -p "代理信息: " proxy
        if [ -z "$proxy" ]; then
            break
        fi
        echo "$proxy" >> "$PROXIES_FILE"
    done

    if [ ! -s "$PROXIES_FILE" ]; then
        echo "错误：未输入任何代理信息"
        echo "按回车键返回主菜单"
        read
        return 1
    fi
}

# 启动 Gradient 函数
function start_gradient() {
    # 首先检查并安装 Docker
    if check_install_docker; then
        echo "Docker 和 Docker Compose 安装或已存在，继续执行..."
        # 检查目录是否存在
        if [ -d "$REPO_DIR" ]; then
            echo "目录 $REPO_DIR 已存在"
            read -p "是否删除已存在的目录? (y/n): " confirm
            if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
                rm -rf "$REPO_DIR"
                echo "已删除原有目录"
            else
                echo "操作取消"
                echo "按回车键返回主菜单"
                read
                return 1
            fi
        fi

        # 克隆 GitHub 仓库
        echo "开始克隆仓库..."
        git clone https://github.com/sdohuajia/Gradient.git "$REPO_DIR"

        if [ $? -ne 0 ]; then
            echo "仓库克隆失败"
            echo "按回车键返回主菜单"
            read
            return 1
        fi

        cd "$REPO_DIR" || exit

        echo "Current directory: $(pwd)"
        echo "Checking for proxies file: $PROXIES_FILE"

        # 输入代理信息
        input_proxies

        # 获取用户邮箱
        while true; do
            read -p "请输入您的邮箱地址: " user_email
            if [[ "$user_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
                break
            else
                echo "邮箱格式不正确，请重新输入"
            fi
        done

        # 获取用户密码
        read -s -p "请输入您的密码: " user_password
        echo

        # 停止已存在的容器
        existing_container=$(docker ps -q --filter "ancestor=overtrue/gradient-bot")
        if [ ! -z "$existing_container" ]; then
            echo "停止已存在的容器..."
            docker stop "$existing_container"
        fi

        # 运行新容器
        echo -e "\n开始运行 Docker 容器..."
        docker run -d \
            -e APP_USER="$user_email" \
            -e APP_PASS="$user_password" \
            -v "$PROXIES_FILE:/app/proxies.txt" \
            overtrue/gradient-bot

        if [ $? -eq 0 ]; then
            echo "Docker 容器已成功启动！"
            echo "当前运行的容器："
            docker ps | grep gradient-bot
        else
            echo "Docker 容器启动失败，请检查错误信息"
        fi

        echo -e "\n按回车键返回主菜单"
        read
    else
        echo "Docker 或 Docker Compose 安装失败，请手动安装后重试。"
        echo "按回车键返回主菜单"
        read
        return 1
    fi
}

# 查看 Gradient 日志函数
function view_logs() {
    container_id=$(docker ps -q --filter "ancestor=overtrue/gradient-bot")
    if [ -z "$container_id" ]; then
        echo "没有找到运行中的 Gradient 容器"
    else
        echo "正在显示 Gradient 容器日志 (按 Ctrl+C 退出日志查看)..."
        echo "================================================================"
        docker logs -f "$container_id"
    fi
    
    echo -e "\n按回车键返回主菜单"
    read
}

# 删除 Gradient 容器函数
function remove_container() {
    container_id=$(docker ps -q --filter "ancestor=overtrue/gradient-bot")
    if [ -z "$container_id" ]; then
        echo "没有找到运行中的 Gradient 容器"
    else
        echo "删除 Gradient 容器..."
        docker rm -f "$container_id"
        if [ $? -eq 0 ]; then
            echo "Gradient 容器已成功删除"
        else
            echo "删除容器失败"
        fi
    fi
    
    echo -e "\n按回车键返回主菜单"
    read
}

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "如有问题，可联系推特，仅此只有一个号"
        echo "新建了一个电报群，方便大家交流：t.me/Sdohua"
        echo "================================================================"
        echo "退出脚本，请按键盘 ctrl + C 退出即可"
        echo "请选择要执行的操作:"
        echo "1. 启动 Gradient "
        echo "2. 查看 日志 "
        echo "3. 删除 容器 "
        echo "4) 退出"
        echo "================================================================"
        
        read -p "请输入选项 [1]: " choice
        
        case $choice in
            1)
                start_gradient
                ;;
            2)
                view_logs
                ;;
            3)
                remove_container
                ;;
            4)
                echo "退出脚本。"
                exit 0
                ;;
            *)
                echo "无效的选项，请重新选择"
                sleep 2
                ;;
        esac
    done
}

# 运行主菜单
main_menu
