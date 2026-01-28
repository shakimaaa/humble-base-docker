# humble-base-docker

一个用于快速创建 ROS2 Humble 基础镜像的 Docker 项目，支持 GPU 加速和 GUI 可视化。

## 📋 项目简介

本项目提供了一套完整的 Docker 配置，用于快速构建和运行 ROS2 Humble 开发环境。镜像基于 `osrf/ros:humble-desktop-full`，并预装了常用的开发工具、GPU 支持库和 GUI 相关依赖。

## ✨ 功能特性

- 🚀 **ROS2 Humble 完整桌面版**：基于官方 `humble-desktop-full` 镜像
- 🎮 **GPU 支持**：支持 NVIDIA GPU 加速（需要 NVIDIA Docker 运行时）
- 🖥️ **GUI 可视化**：支持 X11 图形界面，可运行 GUI 应用程序
- 🛠️ **开发工具**：预装常用开发工具（vim、git、cmake、colcon 等）
- 👤 **非 root 用户**：默认使用 `ros` 用户（UID/GID: 1000:1000）运行，更安全
- 📦 **工作空间挂载**：自动挂载项目目录到容器的 `/workspace`

## 📁 文件说明

```
docker/
├── Dockerfile              # Docker 镜像构建文件
├── docker-compose.yml      # Docker Compose 配置文件
├── run.sh                  # 便捷运行脚本（推荐使用）
└── check_uid_gid.sh        # UID/GID 权限检查脚本
```

### 各文件功能

- **Dockerfile**: 定义镜像构建过程，安装所有必要的依赖和工具
- **docker-compose.yml**: 使用 Docker Compose 启动容器的配置文件
- **run.sh**: 一键构建和运行脚本，自动处理 X11 权限和容器管理
- **check_uid_gid.sh**: 检查容器内用户权限配置是否正确

## 🔧 系统要求

### 必需
- Docker（版本 20.10 或更高）
- Linux 系统（已测试 Ubuntu）

### 可选（用于 GPU 支持）
- NVIDIA GPU
- NVIDIA 驱动程序
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

### 可选（用于 GUI 支持）
- X11 显示服务器（Linux 桌面环境通常已包含）

## 🚀 快速开始

### 方法一：使用 run.sh 脚本（推荐）

最简单的方式是使用提供的运行脚本：

```bash
cd docker
chmod +x run.sh
./run.sh
```

脚本会自动：
1. 检查 Docker 和 NVIDIA 运行时（如果可用）
2. 配置 X11 权限
3. 构建镜像（如果不存在）
4. 启动容器

### 方法二：使用 Docker Compose

```bash
cd docker
docker-compose up -d
docker-compose exec ros2-humble bash
```

### 方法三：手动构建和运行

```bash
# 构建镜像
cd docker
docker build -t ros2-humble:latest -f Dockerfile .

# 允许 X11 连接
xhost +local:docker

# 运行容器
docker run -it \
    --name ros2-humble-container \
    --network host \
    --privileged \
    -e DISPLAY=$DISPLAY \
    -e QT_X11_NO_MITSHM=1 \
    -e NVIDIA_VISIBLE_DEVICES=all \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v $HOME/.Xauthority:/home/ros/.Xauthority:rw \
    -v $(dirname $(pwd)):/workspace:rw \
    -v /dev/dri:/dev/dri \
    --runtime=nvidia \
    --gpus all \
    --user 1000:1000 \
    ros2-humble:latest \
    /bin/bash
```

## 📖 使用说明

### 进入容器

如果容器已在运行：

```bash
docker exec -it ros2-humble-container bash
```

### 检查权限配置

运行检查脚本以验证用户权限配置：

```bash
cd docker
chmod +x check_uid_gid.sh
./check_uid_gid.sh
```

### 测试 GUI 支持

在容器内运行：

```bash
xclock
# 或
xeyes
```

如果能看到图形界面，说明 GUI 配置成功。

### 测试 ROS2

```bash
# 在容器内
source /opt/ros/humble/setup.bash
ros2 run demo_nodes_cpp talker
```

在另一个终端：

```bash
docker exec -it ros2-humble-container bash
source /opt/ros/humble/setup.bash
ros2 run demo_nodes_cpp listener
```

### 测试 GPU 支持

```bash
# 在容器内
nvidia-smi
```

如果能看到 GPU 信息，说明 GPU 支持已正确配置。

## ⚙️ 配置说明

### 用户配置

默认使用 `ros` 用户（UID/GID: 1000:1000）。如需修改，可以在构建时传递构建参数：

```bash
docker build \
    --build-arg USERNAME=myuser \
    --build-arg USER_UID=1001 \
    --build-arg USER_GID=1001 \
    -t ros2-humble:latest \
    -f Dockerfile .
```

### 工作空间

项目目录会自动挂载到容器的 `/workspace`。在 `docker-compose.yml` 中，工作空间路径为：

```yaml
volumes:
  - ../:/workspace:rw
```

如需修改，请编辑 `docker-compose.yml` 或 `run.sh` 中的挂载路径。

## 🔍 常见问题

### 1. GUI 应用无法显示

**解决方案：**
- 确保已运行 `xhost +local:docker`
- 检查 `$DISPLAY` 环境变量是否正确
- 确认 `.Xauthority` 文件权限：`chmod 644 ~/.Xauthority`

### 2. 权限问题（无法写入工作空间）

**解决方案：**
- 运行 `check_uid_gid.sh` 检查权限配置
- 确保容器以正确的用户运行（非 root）
- 检查挂载目录的权限

### 3. GPU 不可用

**解决方案：**
- 确认已安装 NVIDIA Container Toolkit
- 检查 `nvidia-smi` 在主机上是否正常工作
- 验证 Docker 运行时：`docker info | grep nvidia`

### 4. 容器启动失败

**解决方案：**
- 检查 Docker 服务是否运行：`sudo systemctl status docker`
- 查看容器日志：`docker logs ros2-humble-container`
- 确保没有端口冲突

## 🛠️ 构建参数

Dockerfile 支持以下构建参数：

- `USERNAME`: 用户名（默认：`ros`）
- `USER_UID`: 用户 UID（默认：`1000`）
- `USER_GID`: 用户 GID（默认：`1000`）

## 📝 注意事项

1. **安全性**：容器以 `privileged` 模式运行，请仅在可信环境中使用
2. **X11 权限**：`xhost +local:docker` 会降低 X11 安全性，使用完毕后可运行 `xhost -local:docker` 恢复
3. **文件权限**：如果主机用户 UID 与容器用户 UID 不匹配，可能会遇到文件权限问题
4. **网络模式**：使用 `host` 网络模式，容器与主机共享网络栈

## 📄 许可证

本项目基于 ROS2 Humble 官方镜像构建，遵循相应的开源许可证。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📚 相关链接

- [ROS2 Humble 官方文档](https://docs.ros.org/en/humble/)
- [Docker 官方文档](https://docs.docker.com/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)
