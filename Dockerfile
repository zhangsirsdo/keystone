FROM fedora
MAINTAINER jlabocki@redhat.com

# This Dockerfile installs the components of Keystone in a docker image as a proof of concept

#Timestamps are always useful
RUN date > /root/date

#Install required packages
RUN yum install -y python-pbr
RUN yum install -y git
RUN yum install -y python-devel
RUN yum install -y python-setuptools
RUN yum install -y python-pip
RUN yum install -y gcc
RUN yum install -y gcc-devel
RUN yum install -y libxml2-python
RUN yum install -y libxslt-python
RUN yum install -y python-lxml
RUN yum install -y sqlite
RUN yum install -y python-repoze-lru
#RUN yum install python-sqlite2 python-lxml python-greenlet-devel python-ldap sqlite-devel openldap-devel -y

#Clone Keystone and setup
WORKDIR /opt
RUN git clone http://github.com/openstack/keystone.git
WORKDIR /opt/keystone
RUN python setup.py install

#Configure Keystone
RUN mkdir -p /etc/keystone
RUN cp etc/keystone.conf.sample /etc/keystone/keystone.conf
RUN cp etc/keystone-paste.ini /etc/keystone/
RUN sed -ri 's/#driver=keystone.identity.backends.sql.Identity/driver=keystone.identity.backends.sql.Identity/' /etc/keystone/keystone.conf 
RUN sed -ri 's/#connection=<None>/connection=sqlite:\/\/\/keystone.db/' /etc/keystone/keystone.conf
RUN sed -ri 's/#idle_timeout=3600/idle_timeout=200/' /etc/keystone/keystone.conf
RUN sed -ri 's/#admin_token=ADMIN/admin_token=ADMIN/' /etc/keystone/keystone.conf

# The following sections build a script that will be executed on launch via ENTRYPOINT

## Start Keystone
RUN echo "#!/bin/bash" > /root/postlaunchconfig.sh
RUN echo "/usr/bin/keystone-manage db_sync" >> /root/postlaunchconfig.sh
RUN echo "/usr/bin/keystone-all &" >> /root/postlaunchconfig.sh

## Create Services
#I'm not sure if exporting works, so I just specify these environment variables on each command, but it might be cleaner to test this
#RUN export OS_SERVICE_ENDPOINT=http://localhost:35357/v2.0
#RUN export OS_SERVICE_TOKEN=ADMIN
#RUN export OS_AUTH_URL=http://127.0.0.1:35357/v2.0/
RUN echo '/usr/bin/keystone --os_auth_url http://127.0.0.1:35357/v2.0/ --os-token ADMIN --os-endpoint http://127.0.0.1:35357/v2.0/ service-create --name=ceilometer --type=metering --description="Ceilometer Service"' >> /root/postlaunchconfig.sh
RUN echo '/usr/bin/keystone --os_auth_url http://127.0.0.1:35357/v2.0/ --os-token ADMIN --os-endpoint http://127.0.0.1:35357/v2.0/ service-create --name=keystone --type=identity --description="OpenStack Identity"' >> /root/postlaunchconfig.sh
RUN chmod 755 /root/postlaunchconfig.sh

#This you will need to substitute your values and run later - the values are:
# CEILOMETER_SERVICE = the id of the service created by the keystone service-create command
# KEYSTONE_SERVICE = the id of the service created by the keystone service-create command
# CEILOMETER_SERVICE_HOST = the host where the Ceilometer API is running
# KEYSTONE_SERVICE_HOST = the host where the Keystone API is running
RUN echo 'keystone --os_auth_url http://127.0.0.1:35357/v2.0/ --os-token ADMIN --os-endpoint http://127.0.0.1:35357/v2.0/ endpoint-create --region RegionOne --service_id $KEYSTONE_SERVER --publicurl "http://KEYSTONE_SERVICE_HOST:5000/v2.0" --internalurl "http://KEYSTONE_SERVICE_HOST:5000/v2.0" --adminurl "http://KEYSTONE_SERVICE_HOST:35357/v2.0"' > /root/postlaunchconfig.sh
RUN echo 'keystone --os_auth_url http://127.0.0.1:35357/v2.0/ --os-token ADMIN --os-endpoint http://127.0.0.1:35357/v2.0/ endpoint-create --region RegionOne --service_id $CEILOMETER_SERVICE --publicurl "http://CEILOMETER_SERVICE_HOST:8777/"  --adminurl "http://CEILOMETER_SERVICE_HOST:8777/" --internalurl "http://CEILOMETER_SERVICE_HOST:8777/"' > /root/postlaunchconfig.sh
