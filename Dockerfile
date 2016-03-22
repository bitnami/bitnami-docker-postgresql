FROM gcr.io/stacksmith-images/ubuntu:14.04-r05
MAINTAINER Bitnami <containers@bitnami.com>

ENV BITNAMI_APP_NAME=postgresql \
    BITNAMI_APP_USER=postgres \
    BITNAMI_APP_VERSION=9.4.5-0 \
    POSTGRESQL_PACKAGE_SHA256="71a44e9ea3599cacb078729c1e006f7b3b20a6c2316e6933fd0497b46665345a"

ENV BITNAMI_APP_DIR=/opt/bitnami/$BITNAMI_APP_NAME \
    BITNAMI_APP_VOL_PREFIX=/bitnami/$BITNAMI_APP_NAME

ENV PATH=$BITNAMI_APP_DIR/bin:$PATH

RUN bitnami-pkg unpack $BITNAMI_APP_NAME-$BITNAMI_APP_VERSION

# these symlinks should be setup by harpoon at unpack
RUN mkdir -p $BITNAMI_APP_VOL_PREFIX && \
    ln -s $BITNAMI_APP_DIR/data $BITNAMI_APP_VOL_PREFIX/data && \
    ln -s $BITNAMI_APP_DIR/conf $BITNAMI_APP_VOL_PREFIX/conf && \
    ln -s $BITNAMI_APP_DIR/logs $BITNAMI_APP_VOL_PREFIX/logs

COPY rootfs/ /

EXPOSE 5432

VOLUME ["$BITNAMI_APP_VOL_PREFIX/data"]

ENTRYPOINT ["/app-entrypoint.sh"]
CMD ["harpoon", "start", "--foreground", "postgresql"]
