FROM ubuntu:trusty

# The paths where everything will go
ARG INSTALL_BASE=/opt
ARG TOMCAT_BASE=$INSTALL_BASE/tomcat
ARG OPENGROK_BASE=$INSTALL_BASE/opengrok
ARG OPENGROK_DATA=/var/opengrok
ARG SOURCE_BASE=/srv/sources

ARG TOMCAT_UID=11011001
ARG TOMCAT_GID=11011002

# Where we are getting the installers from
ARG TOMCAT_URL=http://mirrors.ukfast.co.uk/sites/ftp.apache.org/tomcat/tomcat-8/v8.5.11/bin/apache-tomcat-8.5.11.tar.gz
ARG OPENGROK_URL=https://github.com/OpenGrok/OpenGrok/files/757802/opengrok-0.13-rc9.tar.gz.zip

# Java options
ARG EXTRA_JAVA_OPTS
ARG EXTRA_CATALINA_OPTS

# Universal ctags has no releases yet so instead we point to a specific commit
ARG CTAGS_COMMIT=74b4371

# Stuff that could be useful to know inside the image
ENV ROOM11_INSTALL_BASE $INSTALL_BASE
ENV ROOM11_TOMCAT_BASE $TOMCAT_BASE
ENV ROOM11_OPENGROK_BASE $OPENGROK_BASE
ENV ROOM11_OPENGROK_DATA $OPENGROK_DATA
ENV ROOM11_SOURCE_BASE $SOURCE_BASE

# Can't add-repository without this
RUN apt-get update
RUN apt-get -y install software-properties-common

# Add Oracle java repo
RUN add-apt-repository -y ppa:webupd8team/java
RUN apt-get update

# Accept the Oracle license
# http://askubuntu.com/a/190674/296695
RUN echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
RUN echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections

# Install everything and his wife
RUN apt-get -y install autotools-dev make autoconf libtool pkg-config git zip unzip oracle-java8-installer

# Stuff that makes Java work properly - do it *after* installation to avoid confusing the installer :-(
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle/jre
ENV CATALINA_HOME $TOMCAT_BASE
ENV JAVA_OPTS -Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom $EXTRA_JAVA_OPTS
ENV CATALINA_OPTS -server $EXTRA_CATALINA_OPTS

# Install universal ctags
RUN git clone https://github.com/universal-ctags/ctags   && \
    cd ctags                                             && \
    git checkout $CTAGS_COMMIT                           && \
    ./autogen.sh                                         && \
    ./configure                                          && \
    make                                                 && \
    make install                                         && \
    cd ..                                                && \
    rm -rf ctags

# Clean up autotools crud
RUN apt-get -y purge --auto-remove autotools-dev make autoconf libtool pkg-config

# Install tomcat
RUN wget -O tomcat.tar.gz "$TOMCAT_URL"
RUN mkdir "$TOMCAT_BASE"
RUN tar -xzvf tomcat.tar.gz -C "$TOMCAT_BASE" --strip-components=1
RUN rm -f tomcat.tar.gz

# Create a user for tomcat
RUN groupadd tomcat -g $TOMCAT_GID
RUN useradd -s /bin/false -u $TOMCAT_UID -g tomcat -d "$TOMCAT_BASE" tomcat
RUN chown -R tomcat.tomcat "$TOMCAT_BASE"
RUN chmod -R g+r "$TOMCAT_BASE/conf"
RUN chmod g+x "$TOMCAT_BASE/conf"

# Install opengrok
RUN wget -O opengrok.tar.gz.zip "$OPENGROK_URL"
RUN mkdir opengrok.tmp "$OPENGROK_BASE"
RUN unzip -d opengrok.tmp opengrok.tar.gz.zip
RUN tar -xzvf opengrok.tmp/*.tar.gz -C "$OPENGROK_BASE" --strip-components=1
RUN rm -rf opengrok.tmp opengrok.tar.gz.zip

# Modify the listen address for the opengrok config update socket
RUN mkdir source.tmp                                             && \
    cd source.tmp                                                && \
    unzip -d . "$OPENGROK_BASE/lib/source.war" WEB-INF/web.xml   && \
    sed -i s/localhost:2424/0.0.0.0:2424/ WEB-INF/web.xml        && \
    zip "$OPENGROK_BASE/lib/source.war" WEB-INF/web.xml          && \
    cd ..                                                        && \
    rm -rf source.tmp

# Deploy opengrok
RUN OPENGROK_TOMCAT_BASE=$TOMCAT_BASE $OPENGROK_BASE/bin/OpenGrok deploy

# We don't need zip/unzip any more
RUN apt-get -y purge --auto-remove zip unzip

