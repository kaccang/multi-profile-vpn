# VPN Multi-Profile Manager - Profile Container
# Ubuntu-based container with Xray, SSH, and vnstat

FROM ubuntu:24.04

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Jakarta

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    supervisor \
    openssh-server \
    vnstat \
    net-tools \
    iptables \
    ca-certificates \
    tzdata \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Install Xray-core
ARG XRAY_VERSION=v25.10.15
RUN mkdir -p /usr/local/xray && \
    wget -O /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip" && \
    unzip /tmp/xray.zip -d /usr/local/xray && \
    chmod +x /usr/local/xray/xray && \
    ln -s /usr/local/xray/xray /usr/local/bin/xray && \
    rm /tmp/xray.zip

# Create necessary directories
RUN mkdir -p /var/run/sshd \
    /etc/xray \
    /var/log/xray \
    /var/log/supervisor \
    /root/.ssh

# Configure SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "AllowUsers root" >> /etc/ssh/sshd_config

# Initialize vnstat database (will be created automatically by vnstatd on first run)
RUN mkdir -p /var/lib/vnstat

# Copy supervisor configuration
COPY supervisor.conf /etc/supervisor/conf.d/supervisord.conf

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose SSH port (will be mapped to custom port per profile)
EXPOSE 22

# Expose Xray ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -f xray && pgrep -f sshd || exit 1

# Start supervisor
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
