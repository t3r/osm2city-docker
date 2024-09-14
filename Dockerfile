#Build environment for simgear
FROM debian:bookworm AS simgear-builder

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
  apt-get update && apt-get install -y --no-install-recommends \
  git \
  build-essential \
  freeglut3-dev \
  libboost-dev \
  libcurl4-openssl-dev \
  liblzma-dev \
  libopenal-dev \
  libopenscenegraph-dev \
  zlib1g-dev \
  ca-certificates \
  cmake 

# plain simgear w/o build env
FROM simgear-builder AS simgear
WORKDIR /app

RUN git clone --depth 1 -b release/2020.3 --single-branch https://git.code.sf.net/p/flightgear/simgear simgear \
    && mkdir -p simgear/build \
    && cd simgear/build \
    && cmake -G "Unix Makefiles" \
             -D CMAKE_BUILD_TYPE=Release \
             -D CMAKE_PREFIX_PATH="/usr/local" \
             -D CMAKE_INSTALL_PREFIX:PATH=/usr/local \
             -D ENABLE_RTI=OFF \
             -D ENABLE_TESTS=OFF \
             -D ENABLE_SOUND=OFF \
             -D USE_AEONWAVE=OFF \
             -D ENABLE_PKGUTIL=OFF \
             -D ENABLE_SIMD=OFF \
             .. \
    && make && make install

# runnable fgelev (elevation probe)
FROM simgear AS fgelev-build

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
  apt-get update && apt-get install -y --no-install-recommends \
  libplib-dev

WORKDIR /app

RUN git clone --depth 1 -b release/2020.3 --single-branch https://git.code.sf.net/p/flightgear/flightgear flightgear \
    && mkdir -p flightgear/build \
    && cd flightgear/build \
    && cmake -G "Unix Makefiles" \
             -D CMAKE_BUILD_TYPE=Release \
             -D ENABLE_AUTOTESTING=Off \
             .. \
    && cd utils/fgelev && make && make install && \
    strip /usr/local/bin/fgelev

# build osm2city
FROM simgear-builder AS osm2city-builder

# cd osm2city; for patch in ../patches/osm2city/*.patch; do git am $patch; done; cd ..

WORKDIR /app
COPY patches patches
RUN git config --global user.email "osm2city-patcher@flightgear.org" && \
    git config --global user.name "osm2city patcher" && \
    git clone https://gitlab.com/t3r/osm2city.git && \
    git clone https://gitlab.com/osm2city/osm2city-data.git && \
    rm -rf osm2city/.git && \
    rm -rf osm2city-data/.git && \
    chown 1000:1000 /app -R

# base image for importing osm data into postgres
FROM debian:bookworm AS base
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
  apt-get update && apt-get install -y --no-install-recommends \
  bc \
  jq \
  osmium-tool \
  osmosis \
  postgresql-client \
  && apt-get clean && \
  groupadd -g 1000 appuser && \
  useradd -u 1000 -g 1000 -m appuser --home-dir /app

FROM base AS importer
COPY ./scripts /app/scripts
WORKDIR /app
USER appuser

# image for fgelev w/o build environment
FROM debian:bookworm AS fgelev
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
  apt-get update && apt-get install -y --no-install-recommends \
  openscenegraph && \
  apt-get clean

COPY --from=fgelev-build /usr/local/bin/fgelev /usr/local/bin
COPY empty-propertylist.xml /usr/local/lib/FlightGear/defaults.xml
COPY empty-propertylist.xml /usr/local/lib/FlightGear/Materials/default/materials.xml

# the builder imager to run osm2city, fgelev included
FROM fgelev AS builder
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
  apt-get update && apt-get install -y --no-install-recommends \
  bc \
  jq \
  parallel \
  python3 python3-pip \
  xz-utils \
  && apt-get clean && \
  groupadd -g 1000 appuser && \
  useradd -u 1000 -g 1000 -m appuser --home-dir /app

COPY --from=osm2city-builder /app/osm2city /app/osm2city
COPY --from=osm2city-builder /app/osm2city-data /app/osm2city-data

WORKDIR /app

COPY requirements.txt .
RUN /usr/bin/pip install -r requirements.txt --break-system-packages
COPY ./scripts /app/scripts


RUN mkdir -p scenery && \
    mkdir -p fg_root && \
    chown appuser:appuser /app/scenery /app/fg_root 

COPY requirements.txt .
RUN /usr/bin/pip install -r requirements.txt --break-system-packages

COPY params.ini /app/params.ini

COPY --from=fgelev-build /app/flightgear/scripts/python/TerraSync /usr/local/bin

VOLUME /app/scenery
VOLUME /app/fg_root

ENV FG_ROOT=/app/fg_root

WORKDIR /app
USER appuser

