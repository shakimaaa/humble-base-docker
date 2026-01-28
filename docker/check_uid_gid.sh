#!/bin/bash

# UID/GID 检查脚本
# 用于验证容器内的用户权限配置是否正确

echo "=========================================="
echo "UID/GID 检查工具"
echo "=========================================="
echo ""

# 检查主机上的当前用户UID/GID
echo "【主机信息】"
echo "当前用户: $(whoami)"
echo "UID: $(id -u)"
echo "GID: $(id -g)"
echo "完整ID信息: $(id)"
echo ""

# 检查容器是否存在
if docker ps -a | grep -q ros2-humble-container; then
    echo "【容器信息】"
    echo "检测到容器: ros2-humble-container"
    echo ""
    
    # 检查容器内的用户信息
    echo "【容器内用户信息】"
    echo "当前用户:"
    docker exec ros2-humble-container whoami 2>/dev/null || echo "容器未运行，无法检查"
    echo ""
    echo "UID/GID:"
    docker exec ros2-humble-container id 2>/dev/null || echo "容器未运行，无法检查"
    echo ""
    echo "用户详细信息:"
    docker exec ros2-humble-container cat /etc/passwd | grep -E "(ros|1000)" 2>/dev/null || echo "容器未运行，无法检查"
    echo ""
    
    # 检查工作目录权限
    echo "【工作目录权限】"
    docker exec ros2-humble-container ls -ld /workspace 2>/dev/null || echo "容器未运行，无法检查"
    echo ""
    
    # 检查是否可以写入工作目录
    echo "【写入权限测试】"
    if docker exec ros2-humble-container touch /workspace/.test_write 2>/dev/null; then
        echo "✓ 可以写入 /workspace"
        docker exec ros2-humble-container rm -f /workspace/.test_write 2>/dev/null
    else
        echo "✗ 无法写入 /workspace（可能是权限问题）"
    fi
    echo ""
    
    # 检查是否是root用户
    echo "【权限检查】"
    if docker exec ros2-humble-container test "$(id -u)" -eq 0 2>/dev/null; then
        echo "⚠️  警告: 容器正在以 root 用户运行！"
    else
        echo "✓ 容器正在以非 root 用户运行"
        echo "  用户UID: $(docker exec ros2-humble-container id -u 2>/dev/null)"
        echo "  用户GID: $(docker exec ros2-humble-container id -g 2>/dev/null)"
    fi
    echo ""
else
    echo "【容器信息】"
    echo "未找到容器: ros2-humble-container"
    echo "请先运行 ./run.sh 启动容器"
    echo ""
fi

# 检查镜像中的用户配置
echo "【镜像配置】"
if docker images | grep -q ros2-humble; then
    echo "镜像存在: ros2-humble:latest"
    echo "检查镜像中的用户配置:"
    docker run --rm ros2-humble:latest id 2>/dev/null || echo "无法检查镜像"
    echo ""
else
    echo "镜像不存在: ros2-humble:latest"
    echo "请先构建镜像"
    echo ""
fi

echo "=========================================="
echo "检查完成"
echo "=========================================="
echo ""
echo "提示："
echo "  - 如果容器以 root (UID 0) 运行，说明配置有问题"
echo "  - 理想情况下，容器应该以 UID 1000 (ros用户) 运行"
echo "  - 主机UID和容器UID匹配可以避免文件权限问题"
