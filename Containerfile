# phpBB for forum.catram.org: a release from download.phpbb.com, checked
# against its published SHA-256, with overlay/ (third-party extensions,
# styles and languages) copied on top, on PHP and Apache.

FROM docker.io/library/php:8.3-apache

# PHP extensions: mysqli for the database, gd for the image CAPTCHA and
# thumbnails, apcu for the cache. Build dependencies are removed afterwards.
RUN set -eux; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends libfreetype-dev libjpeg62-turbo-dev libpng-dev; \
	docker-php-ext-configure gd --with-freetype --with-jpeg; \
	docker-php-ext-install -j "$(nproc)" gd mysqli opcache; \
	pecl install apcu; \
	docker-php-ext-enable apcu; \
	rm -rf /tmp/pear; \
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
		| sort -u \
		| xargs -r dpkg-query --search \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

RUN a2enmod remoteip rewrite headers
COPY apache.conf /etc/apache2/sites-available/000-default.conf
COPY php.ini /usr/local/etc/php/conf.d/phpbb.ini

# phpBB and the add-ons pinned in extensions.tsv, styles.tsv and
# languages.tsv, each download checked against its SHA-256 (see install.sh).
ARG PHPBB_VERSION=3.3.19
WORKDIR /var/www/html
COPY install.sh extensions.tsv styles.tsv languages.tsv /tmp/build/
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends curl unzip; \
	sh /tmp/build/install.sh "$PHPBB_VERSION" /var/www/html; \
	rm -rf /tmp/build; \
	apt-get purge -y --auto-remove curl unzip; \
	rm -rf /var/lib/apt/lists/*

# Anything not on the CDB, laid out as in the forum's root
# (ext/<vendor>/<name>, styles/<name>, language/<code>).
COPY overlay/ /var/www/html/

COPY config.php /var/www/html/config.php

# Code stays owned by root and read-only to Apache. These are mounted from the
# host and must be writable by www-data; cache can be a tmpfs, emptied on each
# start so a new release never runs on an old cache.
RUN set -eux; \
	rm -f /var/www/html/.gitkeep; \
	for dir in cache store files images/avatars/upload; do \
		mkdir -p "/var/www/html/$dir"; \
		chown www-data:www-data "/var/www/html/$dir"; \
	done
VOLUME ["/var/www/html/store", "/var/www/html/files", "/var/www/html/images/avatars/upload"]
