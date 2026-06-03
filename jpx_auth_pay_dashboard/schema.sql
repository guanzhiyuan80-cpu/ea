CREATE DATABASE IF NOT EXISTS `jpx_auth_pay_dashboard` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `jpx_auth_pay_dashboard`;

CREATE TABLE IF NOT EXISTS `admins` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `username` VARCHAR(64) NOT NULL UNIQUE,
    `password_hash` VARCHAR(255) NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_login_at` DATETIME NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='管理员';

CREATE TABLE IF NOT EXISTS `accounts` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_login` VARCHAR(32) NOT NULL,
    `server_name` VARCHAR(100) NOT NULL,
    `customer_name` VARCHAR(100) NOT NULL,
    `product` VARCHAR(32) NOT NULL DEFAULT 'XAUUSD',
    `license_code` TEXT NULL,
    `expires_at` DATETIME NULL,
    `last_paid_at` DATETIME NULL,
    `latest_license_id` INT UNSIGNED NULL,
    `last_heartbeat_at` DATETIME NULL,
    `admin_note` TEXT NULL,
    `created_by` VARCHAR(64) NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_account_server` (`account_login`, `server_name`),
    KEY `idx_customer` (`customer_name`),
    KEY `idx_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='授权账号';

CREATE TABLE IF NOT EXISTS `renew_orders` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` INT UNSIGNED NOT NULL,
    `order_no` VARCHAR(64) NOT NULL,
    `amount_yuan` DECIMAL(10,2) NOT NULL,
    `months` INT UNSIGNED NOT NULL DEFAULT 1,
    `status` ENUM('pending','paid','failed','closed') NOT NULL DEFAULT 'pending',
    `code_url` TEXT NULL,
    `wx_transaction_id` VARCHAR(128) NULL,
    `notify_raw` MEDIUMTEXT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `paid_at` DATETIME NULL,
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_order_no` (`order_no`),
    KEY `idx_account` (`account_id`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='续费支付订单';

CREATE TABLE IF NOT EXISTS `license_history` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` INT UNSIGNED NOT NULL,
    `order_id` INT UNSIGNED NULL,
    `license_code` TEXT NOT NULL,
    `starts_at` DATETIME NOT NULL,
    `expires_at` DATETIME NOT NULL,
    `amount_yuan` DECIMAL(10,2) NOT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_account` (`account_id`),
    KEY `idx_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='授权码生成历史';

CREATE TABLE IF NOT EXISTS `heartbeat_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` INT UNSIGNED NULL,
    `account_login` VARCHAR(32) NOT NULL,
    `server_name` VARCHAR(100) NOT NULL,
    `authorized` TINYINT(1) NOT NULL DEFAULT 0,
    `ip_address` VARCHAR(45) NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_account_time` (`account_login`, `server_name`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='EA心跳日志';

CREATE TABLE IF NOT EXISTS `trade_reports` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` INT UNSIGNED NULL,
    `account_login` VARCHAR(32) NOT NULL,
    `server_name` VARCHAR(100) NOT NULL,
    `customer_name` VARCHAR(100) NULL,
    `report_time` DATETIME NOT NULL,
    `balance` DECIMAL(15,2) NOT NULL DEFAULT 0,
    `equity` DECIMAL(15,2) NOT NULL DEFAULT 0,
    `floating_profit` DECIMAL(15,2) NOT NULL DEFAULT 0,
    `realized_profit` DECIMAL(15,2) NOT NULL DEFAULT 0,
    `open_positions` INT NOT NULL DEFAULT 0,
    `total_exposure` DECIMAL(15,2) NOT NULL DEFAULT 0,
    `raw_json` MEDIUMTEXT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_account_time` (`account_login`, `server_name`, `report_time`),
    KEY `idx_customer_time` (`customer_name`, `report_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='EA盈亏快照';

CREATE TABLE IF NOT EXISTS `trade_history` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` INT UNSIGNED NULL,
    `account_login` VARCHAR(32) NOT NULL,
    `server_name` VARCHAR(100) NOT NULL,
    `deal_ticket` VARCHAR(64) NOT NULL,
    `symbol` VARCHAR(32) NOT NULL,
    `deal_type` VARCHAR(16) NOT NULL,
    `entry_type` VARCHAR(16) NOT NULL,
    `volume` DECIMAL(10,2) NOT NULL DEFAULT 0,
    `price` DECIMAL(15,5) NOT NULL DEFAULT 0,
    `profit` DECIMAL(15,2) NOT NULL DEFAULT 0,
    `commission` DECIMAL(15,2) NOT NULL DEFAULT 0,
    `swap` DECIMAL(15,2) NOT NULL DEFAULT 0,
    `total_pnl` DECIMAL(15,2) NOT NULL DEFAULT 0,
    `deal_time` DATETIME NOT NULL,
    `magic_number` BIGINT NULL,
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_deal` (`account_login`, `server_name`, `deal_ticket`),
    KEY `idx_account_time` (`account_login`, `server_name`, `deal_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='EA成交历史';
