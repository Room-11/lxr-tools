#!/bin/bash

ROOM11_DOCKER_GROUP_NAME=docker
ROOM11_LXR_TOOLS_SERVICE_TYPE=upstart
ROOM11_NGINX_CONF_DIR=/etc/nginx/sites-enabled

# Install some general stuff we need
apt-get update
apt-get -y install git curl linux-image-extra-$(uname -r) linux-image-extra-virtual apt-transport-https ca-certificates nginx

# Install docker
curl -fsSL "$ROOM11_DOCKER_KEY_URL" | sudo apt-key add -
add-apt-repository -y "deb https://apt.dockerproject.org/repo/ ubuntu-$(lsb_release -cs) main"
apt-get update
apt-get -y install docker-engine
