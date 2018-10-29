FROM tomcat:9-jre8
MAINTAINER Nathan Guimaraes "dev.nathan.guimaraes@gmail.com"

#PREPARING OPENGROK BINARIES AND FOLDERS
ADD https://github.com/oracle/opengrok/releases/download/1.1-rc68/opengrok-1.1-rc68.tar.gz /opengrok.tar.gz
RUN tar -zxvf /opengrok.tar.gz && mv opengrok-* /opengrok && \
    mkdir /src && \
    mkdir /data && \
    ln -s /data /var/opengrok && \
    ln -s /src /var/opengrok/src

#INSTALLING DEPENDENCIES
#SSH configuration
RUN apt-get update && apt-get install -y git subversion mercurial unzip openssh-server inotify-tools python3 python3-pip && \
    mkdir /var/run/sshd && \
    echo 'root:root' |chpasswd && \
    sed -ri 's/[ #]*PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -ri 's/[ #]*UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config && \
    python3 -m pip install /opengrok/tools/opengrok-tools*
# compile and install universal-ctags
RUN apt-get install -y pkg-config autoconf build-essential && git clone https://github.com/universal-ctags/ctags /root/ctags && \
    cd /root/ctags && ./autogen.sh && ./configure && make && make install && \
    apt-get remove -y autoconf build-essential && apt-get -y autoremove && apt-get -y autoclean && \
    cd /root && rm -rf /root/ctags

#ENVIRONMENT VARIABLES CONFIGURATION
ENV SRC_ROOT /src
ENV DATA_ROOT /data
ENV OPENGROK_WEBAPP_CONTEXT /
ENV OPENGROK_TOMCAT_BASE /usr/local/tomcat
ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH
ENV CATALINA_BASE /usr/local/tomcat
ENV CATALINA_HOME /usr/local/tomcat
ENV CATALINA_TMPDIR /usr/local/tomcat/temp
ENV JRE_HOME /usr
ENV CLASSPATH /usr/local/tomcat/bin/bootstrap.jar:/usr/local/tomcat/bin/tomcat-juli.jar


# custom deployment to / with redirect from /source
RUN rm -rf /usr/local/tomcat/webapps/* && \
    opengrok-deploy /opengrok/lib/source.war /usr/local/tomcat/webapps && \
    mv "/usr/local/tomcat/webapps/source.war" "/usr/local/tomcat/webapps/ROOT.war" && \
    mkdir "/usr/local/tomcat/webapps/source" && \
    echo '<% response.sendRedirect("/"); %>' > "/usr/local/tomcat/webapps/source/index.jsp"

# disable all file logging
ADD logging.properties /usr/local/tomcat/conf/logging.properties
RUN sed -i -e 's/Valve/Disabled/' /usr/local/tomcat/conf/server.xml

# add our scripts
ADD scripts /scripts
RUN chmod -R +x /scripts

# run
WORKDIR $CATALINA_HOME
EXPOSE 8080
EXPOSE 22
CMD ["/scripts/start.sh"]
