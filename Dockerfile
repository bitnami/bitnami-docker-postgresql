FROM gcr.io/stacksmith-images/ubuntu:14.04-r07
MAINTAINER Bitnami <containers@bitnami.com>

ENV BITNAMI_IMAGE_VERSION=9.4.5-r0 \
    BITNAMI_APP_NAME=postgresql \
    BITNAMI_APP_USER=postgres

RUN bitnami-pkg unpack postgresql-9.4.5-2 --checksum 7d2b675bd66d5ba61bcf1156cfe5fa108a2f0d555dd0f98fad17e2b4b98501a9
ENV PATH=/opt/bitnami/$BITNAMI_APP_NAME/sbin:/opt/bitnami/$BITNAMI_APP_NAME/bin:$PATH

COPY rootfs/ /
ENTRYPOINT ["/app-entrypoint.sh"]
CMD ["harpoon", "start", "--foreground", "postgresql"]

VOLUME ["/bitnami/$BITNAMI_APP_NAME"]

EXPOSE 5432
