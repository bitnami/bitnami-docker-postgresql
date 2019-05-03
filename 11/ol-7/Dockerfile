FROM bitnami/oraclelinux-extras-base:7-r267
LABEL maintainer "Bitnami <containers@bitnami.com>"

ENV BITNAMI_PKG_CHMOD="-R g+rwX" \
    HOME="/" \
    OS_ARCH="x86_64" \
    OS_FLAVOUR="ol-7" \
    OS_NAME="linux"

# Install required system packages and dependencies
RUN install_packages glibc keyutils-libs krb5-libs libcom_err libedit libselinux libxml2 libxslt ncurses-libs openssl-libs pcre xz-libs zlib
RUN rpm -Uvh --nodeps $(repoquery --location nss_wrapper)
RUN . ./libcomponent.sh && component_unpack "postgresql" "11.2.0-0" --checksum 0229e0dbc29e4fd134902f3a97167cdd79f138e1f6a0dc7f507cb118b7086158
COPY rootfs /
RUN /post-unpack.sh

ENV BITNAMI_APP_NAME="postgresql" \
    BITNAMI_IMAGE_VERSION="11.2.0-debian-9-r63" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    PATH="/opt/bitnami/postgresql/bin:$PATH" \
    NSS_WRAPPER_LIB="/usr/lib64/libnss_wrapper.so"

EXPOSE 5432
VOLUME [ "/bitnami/postgresql" "/docker-entrypoint-initdb.d" ]

USER 1001
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/run.sh" ]
