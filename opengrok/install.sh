#!/bin/bash

#####################
#    C O N F I G    #
#####################

ROOM11_INSTALL_BASE="/opt"
ROOM11_TOMCAT_BASE="$ROOM11_INSTALL_BASE/tomcat"
ROOM11_OPENGROK_BASE="$ROOM11_INSTALL_BASE/opengrok"
ROOM11_OPENGROK_DATA="/var/opengrok"
ROOM11_SOURCE_BASE="/srv/sources"

ROOM11_TOMCAT_URL="http://mirrors.ukfast.co.uk/sites/ftp.apache.org/tomcat/tomcat-8/v8.5.11/bin/apache-tomcat-8.5.11.tar.gz"
ROOM11_OPENGROK_URL="https://github.com/OpenGrok/OpenGrok/files/467358/opengrok-0.12.1.6.tar.gz.zip"

ROOM11_JAVA_HOME="/usr/lib/jvm/java-8-oracle/jre"
ROOM11_JAVA_OPTS="-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"
ROOM11_CATALINA_HOME="$ROOM11_TOMCAT_BASE"
ROOM11_CATALINA_OPTS="-server"

ROOM11_DOCKER_REPO="room11/opengrok-base"
ROOM11_DOCKER_KEY_URL="https://yum.dockerproject.org/gpg"

#####################
#   / C O N F I G   #
#####################

# Get some stuff we need
apt-get update
apt-get -y install git curl linux-image-extra-$(uname -r) linux-image-extra-virtual apt-transport-https ca-certificates
curl -fsSL "$ROOM11_DOCKER_KEY_URL" | sudo apt-key add -
add-apt-repository -y "deb https://apt.dockerproject.org/repo/ ubuntu-$(lsb_release -cs) main"
apt-get update
apt-get -y install docker-engine

# Install tomcat
wget "$ROOM11_TOMCAT_URL"
mkdir "$ROOM11_TOMCAT_BASE"
r11_tomcat_archive_name=$(echo "$ROOM11_TOMCAT_URL" | rev | cut -d / -f 1 | rev)
tar -xzvf $r11_tomcat_archive_name -C "$ROOM11_TOMCAT_BASE" --strip-components=1
rm -f "$r11_tomcat_archive_name"

# Create a user and group for tomcat
groupadd tomcat
useradd -s /bin/false -g tomcat -G docker -d "$ROOM11_TOMCAT_BASE" tomcat
chown -R tomcat.tomcat "$ROOM11_TOMCAT_BASE"
chmod -R g+r "$ROOM11_TOMCAT_BASE/conf"
chmod g+x "$ROOM11_TOMCAT_BASE/conf"

# Install opengrok
wget "$ROOM11_OPENGROK_URL"
r11_opengrok_archive_name=$(echo "$ROOM11_OPENGROK_URL" | rev | cut -d / -f 1 | rev)
r11_opengrok_archive_ext=$(echo "$r11_opengrok_archive_name" | rev | cut -d . -f 1 | rev)
if [ "$r11_opengrok_archive_ext" == "zip" ]; then
  apt-get -y install unzip
  unzip "$r11_opengrok_archive_name"
  rm -f "$r11_opengrok_archive_name"
  apt-get -y purge --auto-remove unzip
  r11_opengrok_archive_name=${r11_opengrok_archive_name:0:${#r11_opengrok_archive_name}-${#r11_opengrok_archive_ext}-1}
fi
mkdir "$ROOM11_OPENGROK_DATA" "$ROOM11_OPENGROK_BASE" "$ROOM11_SOURCE_BASE"
chown tomcat.tomcat "$ROOM11_OPENGROK_DATA" "$ROOM11_OPENGROK_BASE" "$ROOM11_SOURCE_BASE"
tar -xzvf "$r11_opengrok_archive_name" -C "$ROOM11_OPENGROK_BASE" --strip-components=1
rm -f "$r11_opengrok_archive_name"

# Deploy opengrok
docker pull room11/opengrok-base
docker run \
       --entrypoint "$ROOM11_OPENGROK_BASE/bin/OpenGrok" \
       -v "$ROOM11_INSTALL_BASE:$ROOM11_INSTALL_BASE:rw" \
       -e "OPENGROK_TOMCAT_BASE=$ROOM11_TOMCAT_BASE" \
       -e "JAVA_HOME=$ROOM11_JAVA_HOME" \
       -e "JAVA_OPTS=$ROOM11_JAVA_OPTS" \
       "$ROOM11_DOCKER_REPO" \
       deploy

# Define the tomcat service
cat << EOD > /etc/init/tomcat.conf
  description "Tomcat Server"

  start on runlevel [2345]
  stop on runlevel [!2345]
  respawn
  respawn limit 10 5

  setuid tomcat
  setgid tomcat

  script
    docker run \\
           --entrypoint $ROOM11_TOMCAT_BASE/bin/catalina.sh \\
           --network=host \\
           -u $(id -u tomcat) \\
           -v '$ROOM11_SOURCE_BASE:$ROOM11_SOURCE_BASE:ro' \\
           -v '$ROOM11_OPENGROK_DATA:$ROOM11_OPENGROK_DATA:rw' \\
           -v '$ROOM11_TOMCAT_BASE:$ROOM11_TOMCAT_BASE:rw' \\
           -e 'JAVA_HOME=$ROOM11_JAVA_HOME' \\
           -e 'JAVA_OPTS=$ROOM11_JAVA_OPTS' \\
           -e 'CATALINA_HOME=$ROOM11_CATALINA_HOME' \\
           -e 'CATALINA_OPTS=$ROOM11_CATALINA_OPTS' \\
           '$ROOM11_DOCKER_REPO' \\
           run
  end script

  post-stop script
    rm -rf '$ROOM11_TOMCAT_BASE/temp/*'
  end script
EOD

# Create the opengrok indexer scripts
cat << EOD > /usr/bin/opengrok-index-all
#!/bin/bash

docker run \\
       --entrypoint $ROOM11_OPENGROK_BASE/bin/OpenGrok \\
       --network=host \\
       -v '$ROOM11_OPENGROK_BASE:$ROOM11_OPENGROK_BASE:ro' \\
       -v '$ROOM11_OPENGROK_DATA:$ROOM11_OPENGROK_DATA:rw' \\
       -v '$ROOM11_SOURCE_BASE:$ROOM11_SOURCE_BASE:ro' \\
       -e 'JAVA_HOME=$ROOM11_JAVA_HOME' \\
       -e 'JAVA_OPTS=$ROOM11_JAVA_OPTS' \\
       '$ROOM11_DOCKER_REPO' \\
       index \\
       '$ROOM11_SOURCE_BASE'
EOD

cat << EOD > /usr/bin/opengrok-index-subtree
#!/bin/bash

docker run \\
       --entrypoint $ROOM11_OPENGROK_BASE/bin/OpenGrok \\
       --network=host \\
       -v '$ROOM11_OPENGROK_BASE:$ROOM11_OPENGROK_BASE:ro' \\
       -v '$ROOM11_OPENGROK_DATA:$ROOM11_OPENGROK_DATA:rw' \\
       -v '$ROOM11_SOURCE_BASE:$ROOM11_SOURCE_BASE:ro' \\
       -e 'JAVA_HOME=$ROOM11_JAVA_HOME' \\
       -e 'JAVA_OPTS=$ROOM11_JAVA_OPTS' \\
       '$ROOM11_DOCKER_REPO' \\
       indexpart \\
       $ROOM11_SOURCE_BASE \\
       \$1
EOD

chown root.root /usr/bin/opengrok-index-all /usr/bin/opengrok-index-subtree
chmod 755 /usr/bin/opengrok-index-all /usr/bin/opengrok-index-subtree

# Start the tomcat service
initctl reload-configuration
initctl start tomcat
