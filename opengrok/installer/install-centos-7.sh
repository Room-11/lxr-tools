#!/bin/bash

ROOM11_DOCKER_GROUP_NAME=dockerroot
ROOM11_LXR_TOOLS_SERVICE_TYPE=systemd
ROOM11_NGINX_CONF_DIR=/etc/nginx/conf.d

# Install some general stuff we need
yum -y install git curl wget nginx
