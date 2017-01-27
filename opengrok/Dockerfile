FROM ubuntu:trusty

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
RUN apt-get -y install autotools-dev make autoconf libtool pkg-config git unzip oracle-java8-installer

# Install universal ctags
RUN git clone https://github.com/universal-ctags/ctags && \
    cd ctags && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install && \
    cd .. && \
    rm -rf ctags

# Clean up
RUN apt-get -y purge --auto-remove autotools-dev make autoconf libtool pkg-config unzip
