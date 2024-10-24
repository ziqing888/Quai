#!/bin/bash

# 定义颜色和样式
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
BOLD="\033[1m"
RESET="\033[0m"

# 日志文件路径
LOG_FILE="/var/log/quai_script.log"

# 日志记录函数
write_log() {
    local message="$1"
    local log_type="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$log_type] $message" >> "$LOG_FILE"
}

log_info() {
    local message="$1"
    echo -e "${BLUE}ℹ ${BOLD}[INFO]${RESET} $message"
    write_log "$message" "INFO"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}✅ ${BOLD}[SUCCESS]${RESET} $message"
    write_log "$message" "SUCCESS"
}

log_error() {
    local message="$1"
    echo -e "${RED}❌ ${BOLD}[ERROR]${RESET} $message"
    write_log "$message" "ERROR"
}

# 选择操作系统
choose_os() {
    while true; do
        echo -e "${BOLD}请选择您的操作系统:${RESET}"
        echo "1) macOS"
        echo "2) Windows (WSL)"
        echo "=============================================="
        read -p "请输入选项 (1 或 2): " os_choice

        case $os_choice in
            1)
                OS="macOS"
                log_info "用户选择 macOS"
                break
                ;;
            2)
                OS="Windows"
                log_info "用户选择 Windows (WSL)"
                break
                ;;
            *)
                echo "无效选项，请重新选择。"
                ;;
        esac
    done

    # 选择操作系统后调用主菜单
    main_menu
}

# 主菜单函数
main_menu() {
    while true; do
        clear
        echo -e "${BOLD}欢迎使用 Quai 节点和矿工管理脚本${RESET}"
        echo "=============================================="
        echo "请选择要执行的操作:"
        echo "1) 安装系统依赖"
        echo "2) 部署 Quai 节点"
        echo "3) 查看 Quai 节点日志"
        echo "4) 部署 Stratum Proxy"
        echo "5) 启动矿工"
        echo "6) 查看挖矿日志"
        echo "7) 退出"
        echo "=============================================="

        read -p "请输入选项: " choice

        case $choice in
            1) install_dependencies ;;
            2) deploy_node ;;
            3) view_logs ;;
            4) deploy_stratum_proxy ;;
            5) start_miner ;;
            6) view_mining_logs ;;
            7) echo "退出脚本..." && exit 0 ;;
            *) echo "无效选项，请重试。" ;;
        esac
    done
}

# 假设的依赖安装函数
install_dependencies() {
    log_info "安装系统依赖..."
    if [[ "$OS" == "macOS" ]]; then
        # macOS 依赖安装
        if ! command -v brew &> /dev/null; then
            echo "安装 Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install git wget curl screen
    elif [[ "$OS" == "Windows" ]]; then
        # Windows (WSL) 依赖安装
        if ! command -v choco &> /dev/null; then
            echo "请先安装 Chocolatey 包管理器。"
            exit 1
        fi
        choco install git wget curl screen
    fi
    log_success "系统依赖安装成功。"
    pause "按任意键返回主菜单..."
}

# 部署节点的函数
deploy_node() {
    log_info "部署 Quai 节点..."

    # 安装 Go
    check_go

    # 创建目录并切换到该目录
    mkdir -p /data/ && cd /data/

    # 克隆 Git 仓库
    log_info "克隆 Quai 节点仓库..."
    git clone https://github.com/dominant-strategies/go-quai

    # 切换到 Quai 目录
    cd go-quai

    # 切换到指定版本
    git checkout v0.38.0

    # 构建项目
    make go-quai

    # 输入地址信息
    read -p '请输入 Quai 地址: ' quai_address
    read -p '请输入 Qi 地址: ' qi_address

    # 启动 Quai 节点
    screen -dmS node bash -c "./build/bin/go-quai start --node.slices '[0 0]' \
    --node.genesis-nonce 6224362036655375007 \
    --node.quai-coinbases '$quai_address' \
    --node.qi-coinbases '$qi_address' \
    --node.miner-preference '0.5'; exec bash"

    log_success "Quai 节点已启动。可以使用 'screen -r node' 查看日志。"
    pause "按任意键返回主菜单..."
}

# 部署 Stratum Proxy
deploy_stratum_proxy() {
    log_info "部署 Stratum Proxy..."
    cd /data/
    git clone https://github.com/dominant-strategies/go-quai-stratum
    cd go-quai-stratum

    # 切换到指定版本
    git checkout v0.16.0

    # 复制配置文件
    cp config/config.example.json config/config.json

    # 构建 Stratum Proxy
    make go-quai-stratum

    # 在 screen 中运行 Stratum Proxy
    screen -dmS stratum bash -c "./build/bin/go-quai-stratum --region=cyprus --zone=cyprus1 --stratum=3333; exec bash"

    log_success "Stratum Proxy 已启动。"
    pause "按任意键返回主菜单..."
}

# 启动矿工
start_miner() {
    log_info "启动矿工..."
    read -p '请输入节点所在 IP 地址: ' node_ip

    # 下载并部署矿工
    log_info "下载并部署矿工..."
    wget https://raw.githubusercontent.com/dominant-strategies/quai-gpu-miner/refs/heads/main/deploy_miner.sh
    chmod +x deploy_miner.sh
    ./deploy_miner.sh

    wget -P /usr/local/bin/ https://github.com/dominant-strategies/quai-gpu-miner/releases/download/v0.2.0/quai-gpu-miner
    chmod +x /usr/local/bin/quai-gpu-miner

    screen -dmS miner bash -c "quai-gpu-miner -U -P stratum://$node_ip:3333 2>&1 | tee /var/log/miner.log"

    log_success "矿工已启动！使用 'screen -r miner' 查看日志。"
    pause "按任意键返回主菜单..."
}

# 查看日志
view_logs() {
    log_info "正在查看节点日志..."
    tail -f /data/go-quai/nodelogs/global.log
}

# 查看挖矿日志
view_mining_logs() {
    log_info "正在查看挖矿日志..."
    grep Accepted /var/log/miner.log
}

# 暂停函数，等待用户按任意键继续
pause() {
    read -rsp "$*" -n1
}

# 检查并安装 Go
check_go() {
    if ! command -v go &> /dev/null || ! go version | grep -q "go1.23"; then
        log_info "Go 未安装，正在安装 Go 1.23..."
        if [[ "$OS" == "macOS" ]]; then
            brew install go
        elif [[ "$OS" == "Windows" ]]; then
            choco install golang
        fi
    else
        log_info "Go 已安装，版本如下："
        go version
    fi
}

# 选择操作系统并启动主菜单
choose_os
