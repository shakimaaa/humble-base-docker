#!/bin/bash

# ROS2 Humble Docker运行脚本
# 支持GPU和X11可视化

REBUILD_IMAGE=false

for arg in "$@"; do
    case "$arg" in
        --rebuild)
            REBUILD_IMAGE=true
            ;;
        *)
            echo "错误: 不支持的参数: $arg"
            echo "用法: $0 [--rebuild]"
            exit 1
            ;;
    esac
done

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "错误: Docker未安装，请先安装Docker"
    exit 1
fi

# 检查NVIDIA Docker运行时（可选，如果没有GPU可以注释掉）
if ! docker info | grep -q nvidia; then
    echo "警告: 未检测到NVIDIA Docker运行时，GPU支持可能不可用"
    echo "如果没有GPU，可以继续运行，但某些功能可能受限"
fi

# 允许X11连接
xhost +local:docker 2>/dev/null || true

# 获取当前目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FASTDDS_XML_HOST_PATH="$SCRIPT_DIR/fastdds.xml"
FASTDDS_XML_CONTAINER_PATH="/workspace/humble-base-docker/fastdds.xml"
DESIRED_SOCKET_BUFFER_SIZE=104857600

if [ ! -f "$FASTDDS_XML_HOST_PATH" ]; then
    echo "错误: 未找到 Fast DDS 配置文件: $FASTDDS_XML_HOST_PATH"
    exit 1
fi

# 确保Xauthority文件权限正确（允许容器内的ros用户访问）
XAUTH_MOUNT_ARGS=()
if [ -f "$HOME/.Xauthority" ]; then
    chmod 644 "$HOME/.Xauthority" 2>/dev/null || true
    XAUTH_MOUNT_ARGS=(-v "$HOME/.Xauthority:/home/ros/.Xauthority:rw")
else
    echo "警告: 未找到 $HOME/.Xauthority，将跳过 Xauthority 挂载"
fi

# 检查宿主机socket buffer上限，Fast DDS XML中的大buffer会受这里限制
HOST_RMEM_MAX="$(sysctl -n net.core.rmem_max 2>/dev/null || echo 0)"
HOST_WMEM_MAX="$(sysctl -n net.core.wmem_max 2>/dev/null || echo 0)"

echo "Fast DDS 配置文件: $FASTDDS_XML_HOST_PATH"
echo "宿主机 socket buffer 上限:"
echo "  net.core.rmem_max = $HOST_RMEM_MAX"
echo "  net.core.wmem_max = $HOST_WMEM_MAX"

if [ "$HOST_RMEM_MAX" -lt "$DESIRED_SOCKET_BUFFER_SIZE" ] || [ "$HOST_WMEM_MAX" -lt "$DESIRED_SOCKET_BUFFER_SIZE" ]; then
    echo ""
    echo "警告: 宿主机 socket buffer 上限低于 Fast DDS XML 期望值 $DESIRED_SOCKET_BUFFER_SIZE"
    echo "这会导致 sendSocketBufferSize/listenSocketBufferSize 无法完全生效。"
    echo "请在宿主机执行以下命令后重试:"
    echo "  sudo sysctl -w net.core.rmem_max=$DESIRED_SOCKET_BUFFER_SIZE"
    echo "  sudo sysctl -w net.core.wmem_max=$DESIRED_SOCKET_BUFFER_SIZE"
    echo "  sudo sysctl -w net.core.rmem_default=$DESIRED_SOCKET_BUFFER_SIZE"
    echo "  sudo sysctl -w net.core.wmem_default=$DESIRED_SOCKET_BUFFER_SIZE"
    echo ""
fi

# 构建镜像（首次构建或显式要求重建）
if [ "$REBUILD_IMAGE" = true ] || ! docker image inspect ros2-humble:latest > /dev/null 2>&1; then
    echo "正在构建Docker镜像..."
    docker build -t ros2-humble:latest -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"
fi

# 如果容器已存在，先删除
# if docker ps -a | grep -q ros2-humble-container; then
#     echo "检测到已存在的容器，正在删除..."
#     docker rm -f ros2-humble-container 2>/dev/null || true
# fi

# 显示主机UID/GID信息（用于参考）
echo "主机用户信息: $(whoami) (UID: $(id -u), GID: $(id -g))"
echo "容器将使用: ros (UID: 1000, GID: 1000)"
echo ""

# 运行容器（强制使用ros用户，UID/GID 1000:1000）
echo "正在启动ROS2 Humble容器（以ros用户运行，UID:1000 GID:1000）..."
docker run -it \
    --name humble-shm \
    --network host \
    --ipc host \
    --privileged \
    -e DISPLAY=$DISPLAY \
    -e QT_X11_NO_MITSHM=1 \
    -e NVIDIA_VISIBLE_DEVICES=all \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v "$PROJECT_DIR":/workspace:rw \
    -v /dev/dri:/dev/dri \
    "${XAUTH_MOUNT_ARGS[@]}" \
    --runtime=nvidia \
    --gpus all \
    --user 1000:1000 \
    ros2-humble:latest \
    /bin/bash -c "echo '容器内用户信息:'; whoami; id; echo ''; echo '工作目录权限:'; ls -ld /workspace; echo ''; echo 'RMW_IMPLEMENTATION='\"\$RMW_IMPLEMENTATION\"; echo 'Fast DDS XML:'; echo \$FASTDDS_DEFAULT_PROFILES_FILE; echo 'RMW_FASTRTPS_USE_QOS_FROM_XML='\"\$RMW_FASTRTPS_USE_QOS_FROM_XML\"; echo ''; echo '提示: 如果看到 root (UID 0)，说明配置有问题'; exec /bin/bash"

# 清理X11权限（可选）
# xhost -local:docker 2>/dev/null || true
