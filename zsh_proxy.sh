#!/bin/bash

# Function to check if the current user can use sudo
can_use_sudo() {
    command -v sudo >/dev/null 2>&1 || return 1
    case "$PREFIX" in
        *com.termux*) return 1 ;;
    esac
  ! LANG= sudo -n -v 2>&1 | grep -q "may not run sudo"
}

fmt_error() {
  printf '\033[1m\033[31mError: %s\033[0m\n' "$*"  >&2
}


detect_package_manager() {
    if command -v apt > /dev/null; then
        echo "apt"
    elif command -v yum > /dev/null; then
        echo "yum"
    elif command -v dnf > /dev/null; then
        echo "dnf"
    elif command -v pacman > /dev/null; then
        echo "pacman"
    elif command -v zypper > /dev/null; then
        echo "zypper"
    else
        echo "unsupported"
    fi
}

install_packages() {
    local package_manager=$1

    case $package_manager in
        apt)
            if [ "$(id -u)" -eq 0 ]; then
                apt update && apt install -y zsh git curl wget
            elif can_use_sudo; then
                sudo apt update && sudo apt install -y zsh git curl wget
            else
                echo "You need to be root or have sudo privileges to install packages."
                exit 1
            fi
            ;;
        yum)
            if [ "$(id -u)" -eq 0 ]; then
                yum install -y zsh git curl wget
            elif can_use_sudo; then
                sudo yum install -y zsh git curl wget
            else
                echo "You need to be root or have sudo privileges to install packages."
                exit 1
            fi
            ;;
        dnf)
            if [ "$(id -u)" -eq 0 ]; then
                dnf install -y zsh git curl wget
            elif can_use_sudo; then
                sudo dnf install -y zsh git curl wget
            else
                echo "You need to be root or have sudo privileges to install packages."
                exit 1
            fi
            ;;
        pacman)
            if [ "$(id -u)" -eq 0 ]; then
                pacman -Syu --noconfirm zsh git curl wget
            elif can_use_sudo; then
                sudo pacman -Syu --noconfirm zsh git curl wget
            else
                echo "You need to be root or have sudo privileges to install packages."
                exit 1
            fi
            ;;
        zypper)
            if [ "$(id -u)" -eq 0 ]; then
                zypper install -y zsh git curl wget
            elif can_use_sudo; then
                sudo zypper install -y zsh git curl wget
            else
                echo "You need to be root or have sudo privileges to install packages."
                exit 1
            fi
            ;;
        *)
            fmt_error "Unsupported package manager. Please install zsh, git, curl, and wget manually."
            exit 1
            ;;
    esac
}

# Function to install git and so on
start_install() {
    echo "下载更新git curl等"
    local package_manager=$(detect_package_manager)
    install_packages "$package_manager"
}

start_install

temp_proxy=""
temp_proxy_set() {
    read -p "是否需要临时代理保证git clone和脚本拉取? (y/n): " choice

    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    
        read -p "请输入代理地址(如http://127.0.0.1:7890),跳过请输入n:" temp_proxy_input
    
        if [[ "$temp_proxy_input" != "n" && "$temp_proxy_input" != "N" && -n "$temp_proxy_input" ]]; then
            temp_proxy="$temp_proxy_input"
        else
            unset temp_proxy
        fi
    else
        unset temp_proxy
    fi
}

temp_proxy_set

if [ -n "$temp_proxy" ]; then
    sh -c  "$(wget -O- https://install.ohmyz.sh/  | sed "/exec zsh -l/d" | sed "s|git fetch|git -c http.proxy=$temp_proxy fetch|" | sed "s/read -r opt/opt=y \&\& echo ' '/")"

    if [ $? -ne 0 ]; then
        fmt_error "oh-my-zsh安装失败"
        exit 1
    fi

    git -c http.proxy=$temp_proxy clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions --depth 1

    git -c http.proxy=$temp_proxy clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting --depth 1
else
    sh -c  "$(wget -O- https://install.ohmyz.sh/  | sed '/exec zsh -l/d' | sed "s/read -r opt/opt=y \&\& echo ' '/")"

    if [ $? -ne 0 ]; then
        fmt_error "oh-my-zsh安装失败"
        exit 1
    fi

    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions --depth 1

    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting --depth 1
fi


sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting extract)/' ~/.zshrc

# 提示用户输入 y 或 n
read -p "是否需要设置当前用户zsh系统代理环境变量? (y/n): " choice

# 检查用户输入
if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    read -p "是否沿用临时代理设置(http_proxy=$temp_proxy https_proxy=$temp_proxy)? (y/n): " answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        echo "export http_proxy=$temp_proxy" >> ~/.zshrc
        echo "export https_proxy=$temp_proxy" >> ~/.zshrc
    else
        # 提示用户输入内容
        read -p "请输入系统代理环境变量(如http://127.0.0.1:7890)，跳过请输入n:" http_proxy

        if [[ "$http_proxy" != "n" && "$http_proxy" != "N" ]]; then
            echo "export http_proxy=$http_proxy" >> ~/.zshrc
            echo "export https_proxy=$http_proxy" >> ~/.zshrc
        fi
    fi
else
    echo "跳过设置代理设置"
fi

chsh -s /bin/zsh

exec zsh -l