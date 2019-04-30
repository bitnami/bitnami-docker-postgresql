FROM bitnami/minideb-extras-base:stretch-r223
LABEL maintainer "Bitnami <containers@bitnami.com>"

ENV BITNAMI_PKG_CHMOD="-R g+rwX" \
    HOME="/" \
    OS_ARCH="amd64" \
    OS_FLAVOUR="debian-9" \
    OS_NAME="linux"

# Install required system packages and dependencies
RUN install_packages libbsd0 libc6 libedit2 libgcc1 libicu57 liblzma5 libncurses5 libnss-wrapper libssl1.1 libstdc++6 libtinfo5 libxml2 libxslt1.1 zlib1g locales
RUN echo 'en_GB.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen
RUN echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen
RUN . ./libcomponent.sh && component_unpack "postgresql" "11.2.0-0" --checksum 9e1a4e02db6b41240d735830b263a1d7190aa55bcf82e664069dc28b4d8ae035
COPY rootfs /
RUN /prepare.sh
RUN mkdir -p /docker-entrypoint-initdb.d /opt/bitnami/postgresql/conf/
RUN chmod -R g+rwX /opt/bitnami/postgresql/conf/

ENV BITNAMI_APP_NAME="postgresql" \
    BITNAMI_IMAGE_VERSION="11.2.0-debian-9-r63" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    NAMI_PREFIX="/.nami" \
    NSS_WRAPPER_LIB="/usr/lib/libnss_wrapper.so" \
    PATH="/opt/bitnami/postgresql/bin:$PATH" \
    POSTGRESQL_CLUSTER_APP_NAME="walreceiver" \
    POSTGRESQL_DATABASE="" \
    POSTGRESQL_INITDB_ARGS="" \
    ALLOW_EMPTY_PASSWORD="yes" \
    POSTGRESQL_DATA_DIR="/bitnami/postgresql" \
    POSTGRESQL_INITDB_WALDIR="" \
    POSTGRESQL_MASTER_HOST="" \
    POSTGRESQL_MASTER_PORT_NUMBER="5432" \
    POSTGRESQL_NUM_SYNCHRONOUS_REPLICAS="0" \
    POSTGRESQL_PASSWORD="" \
    POSTGRESQL_PORT_NUMBER="5432" \
    POSTGRESQL_REPLICATION_MODE="master" \
    POSTGRESQL_REPLICATION_PASSWORD="" \
    POSTGRESQL_REPLICATION_USER="" \
    POSTGRESQL_SYNCHRONOUS_COMMIT_MODE="on" \
    POSTGRESQL_USERNAME="postgres"

EXPOSE 5432

USER 1001
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/run.sh" ]
