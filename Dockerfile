FROM rockylinux:9
LABEL maintainer="ome-devel@lists.openmicroscopy.org.uk"

ENV LANG en_US.utf-8
ENV RHEL_FRONTEND=noninteractive
ARG OMERO_VERSION=5.6.10
ARG OMEGO_ADDITIONAL_ARGS=
ENV OMERODIR=/opt/omero/server/OMERO.server

RUN mkdir /opt/setup
ADD playbook.yml requirements.yml /opt/setup/
WORKDIR /opt/setup

RUN dnf -y install epel-release && \
    dnf -y update && \
    dnf install -y \
        glibc-langpack-en \
        blosc \
        ansible-core \
        sudo \
        ca-certificates \
        rpmdevtools && \
    # adding missing SSL libraries
    curl -L -o /opt/setup/openssl-libs-1.1.1k-12.el8_9.aarch64.rpm \
        https://build.almalinux.org/pulp/content/prod/almalinux-8-baseos-aarch64/Packages/o/openssl-libs-1.1.1k-12.el8_9.aarch64.rpm && \
    rpmdev-extract openssl-libs-1.1.1k-12.el8_9.aarch64.rpm && \
    mv openssl-libs-1.1.1k-12.el8_9.aarch64/usr/lib64/* /usr/lib64 && \
    rm -rf openssl-libs-1.1.1k-12.el8_9.aarch64 && \
    rm openssl-libs-1.1.1k-12.el8_9.aarch64.rpm && \
    # continue installation
    ansible-galaxy install -p /opt/setup/roles -r requirements.yml && \
    ansible-playbook playbook.yml -vvv -e 'ansible_python_interpreter=/usr/bin/python3'\
        -e omero_server_release=$OMERO_VERSION \
        -e omero_server_omego_additional_args="$OMEGO_ADDITIONAL_ARGS" && \
    # cleaning
    dnf remove -y rpmdevtools && \
    dnf -y clean all && \
    rm -rf /opt/Ice-* && \
    rm -rf /var/cache && \
    rm -f /opt/Ice-*.tar.gz && \
    rm -f /opt/omero/server/OMERO.server-*.zip && \
    # replacing libturbojpeg-java
    rm -f /opt/omero/server/OMERO.server-5.6.10-ice36/lib/server/turbojpeg.jar && \
    rm -f /opt/omero/server/OMERO.server-5.6.10-ice36/lib/client/turbojpeg.jar && \
    curl -L -o /opt/omero/server/OMERO.server-5.6.10-ice36/lib/server/turbojpeg.jar \
        https://github.com/eyal-erknet/libjpeg-turbo-java-aarch64/raw/main/libjpeg-turbo-java-0.1.0-SNAPSHOT.jar && \
    cp /opt/omero/server/OMERO.server-5.6.10-ice36/lib/server/turbojpeg.jar /opt/omero/server/OMERO.server-5.6.10-ice36/lib/client/turbojpeg.jar

RUN \
    # download alternative ice binaries
    curl -L -o /opt/setup/ice-3.6.5-aarch64.tar.gz \
        https://github.com/eyal-erknet/Omero-ICE-aarch64/raw/main/ice-3.6.5-aarch64-ssl.tar.gz && \
    tar -xzf /opt/setup/ice-3.6.5-aarch64.tar.gz -C /opt && \
    mv /opt/ice-3.6.5 /opt/Ice-3.6.5 && \
    rm /opt/setup/ice-*.tar.gz

#COPY ansible-role-omero-server-main.tar.gz /opt/setup/opt/setup/ansible-role-omero-server-main.tar.gz
#RUN ansible-galaxy role install -p /opt/setup/roles ./ansible-role-omero-server-main.tar.gz



#RUN dnf -y install cpio
#COPY openssl-libs-1.1.1k-12.el8_9.aarch64.rpm /opt/setup/openssl-libs-1.1.1k-12.el8_9.aarch64.rpm
#COPY openssl-1.1.1k-12.el8_9.aarch64.rpm /opt/setup/openssl-1.1.1k-12.el8_9.aarch64.rpm
#COPY crypto-policies-20230731-1.git3177e06.el8.noarch.rpm /opt/setup/crypto-policies-20230731-1.git3177e06.el8.noarch.rpm
#RUN cd /opt/setup && \
#    rpm2cpio openssl-libs-1.1.1k-12.el8_9.aarch64.rpm | cpio -idmv -D /opt/setup / \
#    mv /opt/setup/usr/lib64/* /usr/lib64/


RUN curl -L -o /usr/local/bin/dumb-init \
    https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_aarch64 && \
    chmod +x /usr/local/bin/dumb-init

ADD entrypoint.sh /usr/local/bin/
ADD 50-config.py 60-database.sh 99-run.sh /startup/

ENV OMERO_TMPDIR=/omero-tmp
RUN mkdir ${OMERO_TMPDIR} && \
    chown -R omero-server: ${OMERO_TMPDIR}

USER omero-server
EXPOSE 4063 4064
ENV PATH=$PATH:/opt/ice/bin
ENV ICE_HOME=/opt/ice
ENV LD_LIBRARY_PATH=/opt/ice/lib64

VOLUME ["/OMERO", "/opt/omero/server/OMERO.server/var"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
