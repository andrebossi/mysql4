# Old image for compitability with older headers required by the build of mysql 4 *2002* software
FROM alpine:3.1

ARG VERSION \
    BUILD_DATE

WORKDIR /usr/local/src

ENV MYSQL_VER="4.1.21"

ADD mysql-${MYSQL_VER}.tar.gz ./

COPY my.cnf /etc/my.cnf
COPY docker-entrypoint.sh /usr/local/bin/

RUN set -x; \
    apk update && \
    apk add tzdata file libstdc++ libtool && \
    apk add --no-cache --virtual .build-deps gcc g++ make tar ncurses-dev bison readline-dev && \
    \
    cd mysql-${MYSQL_VER} && \
    \
    ./configure --without-debug --enable-thread-safe-client --with-big-tables --with-named-thread-libs="-lpthread" && \
    make && \
    make install && \
    apk del .build-deps && \
    \
    mkdir -p /var/db/mysql/tmp/ && \
    mkdir -p /var/log/mysql/ && \
    \
    chmod +x /usr/local/bin/docker-entrypoint.sh && \
    chown mysql:mysql -R /var/db/mysql/ && \
    chown mysql:mysql -R /var/log/mysql && \
    \
    cp -p /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

VOLUME /var/db/mysql

EXPOSE 3306

CMD ["mysqld_safe"]