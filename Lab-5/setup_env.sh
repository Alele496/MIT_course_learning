#!/bin/bash
# setup_mit_env.sh - MIT实验环境一键配置（自动安装Python 2.7）

set -e

echo "=== MIT 6.175 Lab-5实验环境配置 ==="
echo "当前目录: $(pwd)"
echo "系统: $(lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | head -n1)"

# 检查并安装Python 2.7
install_python27() {
    echo "安装Python 2.7..."
    
    # 检查系统类型
    if [ -f /etc/debian_version ]; then
        echo "检测到Debian/Ubuntu系统"
        
        # Ubuntu 20.04及以后版本需要添加PPA
        UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "unknown")
        if [[ "$UBUNTU_VERSION" == "20.04" || "$UBUNTU_VERSION" == "22.04" || "$UBUNTU_VERSION" == "24.04" ]]; then
            echo "Ubuntu $UBUNTU_VERSION - 添加deadsnakes PPA"
            sudo apt update
            sudo apt install -y software-properties-common
            sudo add-apt-repository -y ppa:deadsnakes/ppa
            sudo apt update
            sudo apt install -y python2.7 python2.7-dev
        else
            # 其他Debian/Ubuntu版本
            sudo apt update
            sudo apt install -y python2.7 python2.7-dev python-pip
        fi
        
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS/Fedora
        echo "检测到RHEL/CentOS系统"
        sudo yum install -y python2 python2-pip
        # 创建python2.7软链接（如果python2指向python2.7）
        if [ ! -f /usr/bin/python2.7 ]; then
            sudo ln -sf /usr/bin/python2 /usr/bin/python2.7
        fi
    else
        echo "❌ 无法识别的系统类型，请手动安装Python 2.7"
        exit 1
    fi
    
    # 安装pip for Python 2.7（如果没安装）
    if ! command -v pip2.7 >/dev/null 2>&1 && ! command -v pip2 >/dev/null 2>&1; then
        echo "安装pip for Python 2.7..."
        curl -o get-pip.py https://bootstrap.pypa.io/pip/2.7/get-pip.py
        sudo python2.7 get-pip.py
        rm get-pip.py
    fi
}

# 检查Python 2.7是否已安装
check_python() {
    if command -v python2.7 >/dev/null 2>&1; then
        PYTHON_CMD="python2.7"
        echo "✅ 找到Python 2.7: $(which python2.7)"
        python2.7 --version
        return 0
    elif command -v python2 >/dev/null 2>&1; then
        PYTHON_CMD="python2"
        echo "⚠️  找到python2，检查版本..."
        python2 --version
        # 检查python2是否实际上是2.7版本
        if python2 --version 2>&1 | grep -q "2.7"; then
            echo "✅ Python 2.7 已安装（作为python2）"
            return 0
        else
            return 1
        fi
    else
        echo "❌ 未找到Python 2.7"
        return 1
    fi
}

# 主流程
echo "1. 检查Python 2.7..."
if ! check_python; then
    echo "Python 2.7未安装，开始安装..."
    install_python27
    
    # 再次检查
    if ! check_python; then
        echo "❌ Python 2.7安装失败"
        exit 1
    fi
fi

# 确定Python命令
if command -v python2.7 >/dev/null 2>&1; then
    PYTHON_CMD="python2.7"
elif command -v python2 >/dev/null 2>&1 && python2 --version 2>&1 | grep -q "2.7"; then
    PYTHON_CMD="python2"
else
    echo "❌ 无法找到可用的Python 2.7"
    exit 1
fi

echo "使用Python: $PYTHON_CMD"

# 安装必要工具
echo "2. 安装必要工具..."
if [ -f /etc/debian_version ]; then
    # Debian/Ubuntu
    sudo apt update
    sudo apt install -y curl git make gcc g++
elif [ -f /etc/redhat-release ]; then
    # RHEL/CentOS
    sudo yum install -y curl git make gcc gcc-c++
fi

# 创建项目结构
echo "3. 创建项目结构..."
mkdir -p connectal/scripts

# 下载PLY
echo "4. 下载PLY..."
if [ ! -f "ply-3.9.tar.gz" ]; then
    curl -L https://github.com/dabeaz/ply/archive/refs/tags/3.9.tar.gz -o ply-3.9.tar.gz
else
    echo "PLY存档已存在，跳过下载"
fi

if [ ! -d "ply-3.9" ]; then
    tar -zxf ply-3.9.tar.gz
else
    echo "PLY目录已存在，跳过解压"
fi

# 设置软链接
echo "5. 设置软链接..."
rm -f connectal/scripts/ply 2>/dev/null || true
ln -sf "$(pwd)/ply-3.9/ply" connectal/scripts/ply

# 如果connectal目录不存在，克隆它
if [ ! -d "connectal/.git" ]; then
    echo "6. 克隆connectal仓库..."
    if [ ! -d "connectal" ]; then
        git clone https://github.com/cambridgehackers/connectal
    else
        # 目录存在但不是git仓库
        rm -rf connectal
        git clone https://github.com/cambridgehackers/connectal
    fi
else
    echo "6. connectal仓库已存在"
fi

# 修改Makefile
echo "7. 修改Makefile..."
cd connectal
if [ -f "Makefile" ]; then
    # 备份
    BACKUP_NAME="Makefile.backup.$(date +%Y%m%d_%H%M%S)"
    cp Makefile "$BACKUP_NAME"
    echo "备份Makefile为: $BACKUP_NAME"
    
    # 替换所有python调用
    sed -i "s/python script/$PYTHON_CMD script/g" Makefile
    sed -i "s/python3 script/$PYTHON_CMD script/g" Makefile
    sed -i "s/^\(\s*\)python\(\s\)/\1$PYTHON_CMD\2/g" Makefile
    
    echo "Makefile已修改"
else
    echo "⚠️  Makefile不存在，跳过修改"
fi

cd ..

echo "✅ 环境配置完成"
echo ""
echo "测试:"
echo "1. Python版本: $PYTHON_CMD --version"
echo "2. 测试PLY导入: $PYTHON_CMD -c \"import ply.lex; print('PLY导入成功')\""
echo "=== RISC-V 工具链配置 ==="

if [ ! -x "$RISCV/bin/riscv32-unknown-elf-gcc" ]; then
    echo "❌ 错误：找不到 riscv32-unknown-elf-gcc"
    echo "工具链可能不完整"
    ls "$RISCV/bin/" | head -10
    echo "'RISC-V工具链未找到'"
    echo "3. 检查工具链: riscv32-unknown-elf-gcc --version 或者对应路径是否导出"
    exit 1
else
    echo "✅ 工具链存在: $RISCV"
fi



