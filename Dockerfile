FROM postgres:9.6.2
MAINTAINER Citus Data https://citusdata.com

ENV CITUS_VERSION 6.1.0.citus-1

# build and install cstore_fdw
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       git \
       gcc \
       make \
       protobuf-c-compiler \
       libprotobuf-c0-dev \
       libprotoc-dev \
       postgresql-server-dev-9.6 \
    && git clone https://github.com/citusdata/cstore_fdw /opt/cstore \
    && cd /opt/cstore && make && make install \
    && apt-get purge -y --auto-remove git gcc make

# install Citus
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
    && curl -s https://install.citusdata.com/community/deb.sh | bash \
    && apt-get install -y postgresql-$PG_MAJOR-citus-6.1=$CITUS_VERSION \
    && apt-get purge -y --auto-remove curl \
    && rm -rf /var/lib/apt/lists/*

# install PostGIS
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
           postgresql-9.6-postgis-2.3 \
           postgresql-9.6-postgis-2.3-scripts

# add citus and cstore_fdw to default PostgreSQL config
RUN echo "shared_preload_libraries='citus,cstore_fdw'" >> /usr/share/postgresql/postgresql.conf.sample

# add scripts to run after initdb
COPY 000-symlink-workerlist.sh 001-create-citus-extension.sql 002-create-cstore_fdw-extension.sql 003-create-postgis-extension.sql /docker-entrypoint-initdb.d/

# add our wrapper entrypoint script
COPY citus-entrypoint.sh /

# expose workerlist via volume
VOLUME /etc/citus

ENTRYPOINT ["/citus-entrypoint.sh"]
CMD ["postgres"]
