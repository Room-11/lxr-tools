#!/bin/bash

ROOM11_LXR_TOOLS_SERVICE_INSTALLER=$ROOM11_LXR_TOOLS_BASE_DIR/installer/service-$ROOM11_LXR_TOOLS_SERVICE_TYPE.sh

if [ ! -f $ROOM11_LXR_TOOLS_SERVICE_INSTALLER ]; then
  echo "Unknown service type target: $ROOM11_LXR_TOOLS_SERVICE_TYPE"
  exit 1
fi

if [ ! $(getent group $ROOM11_DOCKER_GROUP_NAME) ]; then
  echo "Group $ROOM11_DOCKER_GROUP_NAME does not exist"
  exit 1
fi

# Get the docker image
docker pull $ROOM11_DOCKER_IMAGE

# Create a user and group for tomcat
# The tomcat user also needs to be in the docker group to access the docker daemon socket
groupadd tomcat
useradd -s /bin/false -g tomcat -G $ROOM11_DOCKER_GROUP_NAME -d "$ROOM11_OPENGROK_DATA" tomcat

# Create the docker bridge network
docker network create --subnet $ROOM11_DOCKER_NETWORK_SUBNET --gateway $ROOM11_DOCKER_NETWORK_GATEWAY $ROOM11_DOCKER_NETWORK_NAME

# Create our install dir
install_base=$ROOM11_INSTALL_BASE/room11-opengrok
install_bin=$install_base/bin
mkdir -p $install_bin

# Create opengrok executables
installer_base=$(dirname $0)
sed                                                           \
  -e s#{MACHINE_IP}#$ROOM11_DOCKER_NETWORK_OPENGROK_IP#g      \
  -e s#{NETWORK_NAME}#$ROOM11_DOCKER_NETWORK_NAME#g           \
  -e s#{SOURCE_BASE}#$ROOM11_SOURCE_BASE#g                    \
  -e s#{OPENGROK_DATA}#$ROOM11_OPENGROK_DATA#g                \
  -e s#{DOCKER_IMAGE}#$ROOM11_DOCKER_IMAGE#g                  \
  -e s#{TOMCAT_BASE}#$ROOM11_TOMCAT_BASE#g                    \
  $installer_base/bin/run-tomcat > $install_bin/run-tomcat
sed                                                           \
  -e s#{SOURCE_BASE}#$ROOM11_SOURCE_BASE#g                    \
  $installer_base/bin/update-all > $install_bin/update-all
sed                                                           \
  -e s#{SOURCE_BASE}#$ROOM11_SOURCE_BASE#g                    \
  -e s#{OPENGROK_DATA}#$ROOM11_OPENGROK_DATA#g                \
  -e s#{DOCKER_IMAGE}#$ROOM11_DOCKER_IMAGE#g                  \
  -e s#{OPENGROK_BASE}#$ROOM11_OPENGROK_BASE#g                \
  $installer_base/bin/index-all > $install_bin/index-all
sed                                                           \
  -e s#{SOURCE_BASE}#$ROOM11_SOURCE_BASE#g                    \
  -e s#{INSTALL_BASE}#$install_base#g                         \
  $installer_base/bin/update-and-index-all > $install_bin/update-and-index-all

# Install indexer cronjob
sed                                                           \
  -e s#{INSTALL_BASE}#$install_base#g                         \
  $installer_base/bin/cronjob > $install_bin/cronjob
ln -s $install_bin/cronjob /etc/cron.hourly/opengrok-update-and-index-all

chmod 755 $install_bin $install_bin/*

# Create tomcat service
source $ROOM11_LXR_TOOLS_SERVICE_INSTALLER

# Add the 'main' log format to main nginx conf file
sed -i 's/\(\s*\)error_log.*/\0\n\1log_format main '"'"'$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" "$http_x_forwarded_for"'"'"';/' /etc/nginx/nginx.conf

# Define the default http host file
sed                                               \
  -e s#{HOST_NAME}#$ROOM11_INSTALL_HOST_NAME#g    \
  -e s#{WEB_ROOT}#$ROOM11_NGINX_WEB_ROOT#g        \
  $installer_base/nginx.http.conf > $ROOM11_NGINX_CONF_DIR/$ROOM11_INSTALL_HOST_NAME.conf

# Create the web root directory
mkdir -p $ROOM11_NGINX_WEB_ROOT/$ROOM11_INSTALL_HOST_NAME/public $ROOM11_NGINX_WEB_ROOT/$ROOM11_INSTALL_HOST_NAME/logs
chown -R www-data.www-data $ROOM11_NGINX_WEB_ROOT

# Reload nginx config
service nginx reload

# Install certbot-auto
wget https://dl.eff.org/certbot-auto
chmod a+x certbot-auto
mv certbot-auto /usr/bin/

# Get a certificate
certbot-auto certonly --webroot -w $ROOM11_NGINX_WEB_ROOT/$ROOM11_INSTALL_HOST_NAME/public -d $ROOM11_INSTALL_HOST_NAME

# Install auto renew cron job
cp $installer_base/../certbot-auto-renew /etc/cron.daily/
chmod 755 /etc/cron.daily/certbot-auto-renew

# Create the ssl_defaults file
cp $installer_base/../nginx.ssl_defaults /etc/nginx/ssl_defaults

# Add HTTPS config
sed                                                                  \
  -e s#{HOST_NAME}#$ROOM11_INSTALL_HOST_NAME#g                       \
  -e s#{WEB_ROOT}#$ROOM11_NGINX_WEB_ROOT#g                           \
  -e s#{FRONT_END_HOST_NAME}#$ROOM11_INSTALL_FRONT_END_HOST_NAME#g   \
  -e s#{OPENGROK_MACHINE_IP}#$ROOM11_DOCKER_NETWORK_OPENGROK_IP#g    \
  $installer_base/nginx.https.conf >> $ROOM11_NGINX_CONF_DIR/$ROOM11_INSTALL_HOST_NAME.conf

# Reload nginx config again
service nginx reload

# hopefully everything should now work...
