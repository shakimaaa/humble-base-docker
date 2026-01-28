# ROS2 Humble Dockerfile with GPU and GUI support
FROM osrf/ros:humble-desktop-full

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

# 安装基础工具和依赖
RUN apt-get update && apt-get install -y \
    # 基础工具
    curl \
    wget \
    git \
    vim \
    nano \
    build-essential \
    cmake \
    # X11和GUI支持
    x11-apps \
    x11-utils \
    x11-xserver-utils \
    xauth \
    xterm \
    # OpenGL和图形库
    libgl1-mesa-glx \
    libgl1-mesa-dri \
    libglu1-mesa \
    libxrandr2 \
    libxss1 \
    libxcursor1 \
    libxcomposite1 \
    libasound2 \
    libxi6 \
    libxtst6 \
    # 网络工具
    net-tools \
    iputils-ping \
    # Python工具
    python3-pip \
    python3-vcstool \
    # 其他有用的工具
    sudo \
    lsb-release \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# 安装colcon构建工具
RUN pip3 install -U \
    colcon-common-extensions \
    colcon-ros \
    vcstool

# 创建非root用户（可选，但推荐）
ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=1000

# 创建用户（如果不存在）
RUN if ! id -u ${USERNAME} > /dev/null 2>&1; then \
    groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo "source /opt/ros/humble/setup.bash" >> /home/${USERNAME}/.bashrc; \
    fi

# 设置工作目录并确保ros用户有权限
WORKDIR /workspace
RUN chown -R ${USERNAME}:${USERNAME} /workspace || true

# 配置ROS2环境
RUN echo "source /opt/ros/humble/setup.bash" >> /etc/bash.bashrc

# 确保ros用户的bashrc配置正确
RUN chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.bashrc || true

# 切换到ros用户（必须在所有需要root权限的操作之后）
USER ${USERNAME}

# 设置默认命令（以ros用户运行）
CMD ["/bin/bash"]
