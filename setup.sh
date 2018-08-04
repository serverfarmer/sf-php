#!/bin/bash
. /opt/farm/scripts/init
. /opt/farm/scripts/functions.install



set_php_option() {
	file=$1
	key=$2
	value=$3

	if ! grep -q ^$key $file; then
		echo >>$file
		echo "$key =" >>$file
	fi

	if [ "$OSVER" = "netbsd-6" ]; then
		sed -e "s/^\($key\)[ =].*/\\1 = $value/" $file >$file.$$
		cat $file.$$ >$file
	else
		sed -i -e "s/^\($key\)[ =].*/\\1 = $value/" $file
	fi
}

process_php_ini() {
	file=$1
	if [ -f $file ]; then
		save_original_config $file

		set_php_option $file error_log '\/var\/log\/php\/php-error.log'
		set_php_option $file include_path '\".:\/usr\/share\/php\"'
		set_php_option $file memory_limit 1536M
		set_php_option $file log_errors On
		set_php_option $file magic_quotes_gpc Off
		set_php_option $file expose_php Off
		set_php_option $file allow_url_fopen Off
		set_php_option $file post_max_size 16M
		set_php_option $file upload_max_filesize 16M
	fi
}

link_php_compat_directory() {
	version=$1
	if [ ! -e /etc/php5 ] && [ -d /etc/php/$version ]; then
		echo "found php $version, creating symlink /etc/php5"
		ln -s /etc/php/$version /etc/php5
	fi
}


if [ -d /usr/local/cpanel ]; then
	echo "skipping php setup, system is controlled by cPanel"
	exit 0
fi

if grep -q php /etc/apt/sources.list 2>/dev/null || grep -q php /etc/apt/sources.list.d/*.list 2>/dev/null; then
	echo "detected custom php version, skipping installing php packages"
else
	/opt/farm/ext/farm-roles/install.sh php-cli
fi

echo "setting up php configuration"
mkdir -p /var/log/php

if [ "$OSTYPE" = "netbsd" ]; then

	chmod 0777 /var/log/php
	process_php_ini /usr/pkg/etc/php.ini

	if [ -f /usr/pkg/bin/php ] && [ ! -f /usr/bin/php5 ]; then
		ln -s /usr/pkg/bin/php /usr/bin/php5
	fi

elif [ "$OSTYPE" = "redhat" ]; then

	chmod 0777 /var/log/php
	process_php_ini /etc/php.ini

	if [ -f /usr/bin/php ] && [ ! -f /usr/bin/php5 ]; then
		ln -s /usr/bin/php /usr/bin/php5
	fi

elif [ "$OSTYPE" = "debian" ]; then

	touch /var/log/php/php-error.log
	chown -R www-data:www-data /var/log/php
	chmod g+w /var/log/php/*.log

	link_php_compat_directory 7.0
	link_php_compat_directory 7.1
	link_php_compat_directory 7.2

	process_php_ini /etc/php5/cli/php.ini
	process_php_ini /etc/php5/cgi/php.ini
	process_php_ini /etc/php5/fpm/php.ini
	process_php_ini /etc/php5/apache2/php.ini
fi
