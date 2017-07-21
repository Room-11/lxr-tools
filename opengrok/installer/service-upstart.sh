#!/bin/bash

sed -e s#{INSTALL_BASE}#$install_base#g $installer_base/tomcat.service.upstart > /etc/init/tomcat.conf
chown root.root /etc/init/tomcat.conf
chmod 644 /etc/init/tomcat.conf
