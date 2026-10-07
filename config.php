<?php
// phpBB's config.php for the image. Values come from the environment, set by
// the Quadlet's env file on the host; nothing secret is in this repository.

$dbms = 'phpbb\\db\\driver\\mysqli';
$dbhost = getenv('PHPBB_DB_HOST') ?: 'mariadb';
$dbport = '';
$dbname = getenv('PHPBB_DB_NAME');
$dbuser = getenv('PHPBB_DB_USER');
$dbpasswd = getenv('PHPBB_DB_PASSWORD');
$table_prefix = getenv('PHPBB_TABLE_PREFIX') ?: 'phpbb_';
$phpbb_adm_relative_path = 'adm/';
$acm_type = 'phpbb\\cache\\driver\\apcu';

@define('PHPBB_INSTALLED', true);
@define('PHPBB_ENVIRONMENT', 'production');
@define('PHPBB_DISPLAY_LOAD_TIME', true);
