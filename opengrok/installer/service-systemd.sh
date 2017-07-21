#!/bin/bash

sed -e s#{INSTALL_BASE}#$install_base#g $installer_base/tomcat.service.systemd > /etc/systemd/system/tomcat.service
chown root.root /etc/systemd/system/tomcat.service
chmod 644 /etc/systemd/system/tomcat.service
