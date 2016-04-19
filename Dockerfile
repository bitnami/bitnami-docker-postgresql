FROM gcr.io/stacksmith-images/ubuntu:14.04-r05
MAINTAINER Bitnami <containers@bitnami.com>

ENV BITNAMI_APP_NAME=postgresql \
    BITNAMI_APP_VERSION=9.4.5-0 \
    BITNAMI_APP_CHECKSUM=71a44e9ea3599cacb078729c1e006f7b3b20a6c2316e6933fd0497b46665345a \
    BITNAMI_APP_USER=postgres

# Install supporting modules
RUN bitnami-pkg unpack $BITNAMI_APP_NAME-$BITNAMI_APP_VERSION --checksum $BITNAMI_APP_CHECKSUM
ENV PATH=/opt/bitnami/$BITNAMI_APP_NAME/bin:$PATH

# Setting entry point
COPY rootfs/ /
ENTRYPOINT ["/app-entrypoint.sh"]
CMD ["harpoon", "start", "--foreground", "postgresql"]

# Exposing ports
EXPOSE 5432

# Exposing volumes
VOLUME ["/bitnami/$BITNAMI_APP_NAME"]
