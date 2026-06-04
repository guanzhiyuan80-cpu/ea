<?php
// Database
define('DB_HOST', '127.0.0.1');
define('DB_PORT', 3306);
define('DB_NAME', 'jpx_auth_pay_dashboard');
define('DB_USER', 'root');
define('DB_PASS', '');

// Admin. Change after first install.
define('DEFAULT_ADMIN_USER', 'admin');
define('DEFAULT_ADMIN_PASSWORD', 'admin123');
define('SESSION_NAME', 'JPX_PAY_ADMIN');

// Business
define('RENEW_AMOUNT_YUAN', 200);
define('RENEW_MONTHS', 1);
define('EXPIRE_WARNING_DAYS', 3);
define('DEFAULT_PRODUCT', 'XAUUSD');
define('API_SHARED_SECRET', 'CHANGE_ME_EA_HTTP_SECRET');

date_default_timezone_set('Asia/Shanghai');
ini_set('display_errors', '0');
error_reporting(E_ALL);
