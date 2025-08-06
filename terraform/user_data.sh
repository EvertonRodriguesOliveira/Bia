#!/bin/bash

# User data script for ECS instances
# This script configures the EC2 instance to join the ECS cluster

# Update the system
yum update -y

# Configure ECS agent
echo ECS_CLUSTER=${cluster_name} >> /etc/ecs/ecs.config
echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config

# Start and enable ECS agent
systemctl start ecs
systemctl enable ecs

# Install CloudWatch agent (optional)
yum install -y amazon-cloudwatch-agent

# Configure log rotation for Docker
cat > /etc/logrotate.d/docker << 'EOF'
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size=1M
    missingok
    delaycompress
    copytruncate
}
EOF
