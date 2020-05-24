FROM jwilder/nginx-proxy:alpine AS builder
RUN echo $NGINX_VERSION

# Set variables
ENV NGX_CACHE_PURGE_MODULE_VERSION 2.5
ENV NGX_CACHE_PURGE_MODULE_URL https://github.com/nginx-modules/ngx_cache_purge/archive/${NGX_CACHE_PURGE_MODULE_VERSION}.tar.gz

# Download sources
# Note: jwilder/nginx-proxy already contains `NGINX_VERSION` environment variable
RUN wget "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -O nginx.tar.gz && \
	wget "${NGX_CACHE_PURGE_MODULE_URL}" -O module.tar.gz

# For the latest build dependencies, see https://github.com/nginxinc/docker-nginx/blob/master/mainline/alpine/Dockerfile
RUN apk add --no-cache --virtual .build-deps \
	gcc \
	libc-dev \
	make \
	openssl-dev \
	pcre-dev \
	zlib-dev \
	linux-headers \
	libxslt-dev \
	gd-dev \
	geoip-dev \
	perl-dev \
	libedit-dev \
	mercurial \
	bash \
	alpine-sdk \
	findutils

# Reuse same CLI arguments as the image to build the module
RUN CONFARGS=$(nginx -V 2>&1 | sed -n -e 's/^.*arguments: //p') \
	mkdir -p /usr/src/nginx && \
	tar -zxC /usr/src/nginx --strip-components 1 --file nginx.tar.gz && \
	mkdir -p /usr/src/module && \
	tar -xzC /usr/src/module --strip-components 1 --file module.tar.gz && \
	MODULE_DIR="/usr/src/module" && \
	cd /usr/src/nginx/ && \
	./configure --with-compat $CONFARGS --add-dynamic-module=$MODULE_DIR && \
	make modules

FROM jwilder/nginx-proxy:alpine

# Set variables
ENV MODULE_FILENAME ngx_http_cache_purge_module
ENV NGINX_MAIN_CONFIG_FILE_PATH /etc/nginx/nginx.conf
ENV NGINX_MODULES_PATH /usr/lib/nginx/modules

# Copy module from builder to the base image
COPY --from=builder /usr/src/nginx/objs/$MODULE_FILENAME.so ${NGINX_MODULES_PATH}/$MODULE_FILENAME.so

# Import module at the start of the main Nginx configuration file
RUN echo "load_module ${NGINX_MODULES_PATH}/${MODULE_FILENAME}.so;$(cat ${NGINX_MAIN_CONFIG_FILE_PATH})" > ${NGINX_MAIN_CONFIG_FILE_PATH}

