<?php
/**
 * 一键安装：建库 / 建表 / 写入默认管理员
 * 浏览器访问  http://你的域名/build/install.php
 * 或  CLI  执行：  php install.php
 *
 * 安装完成后建议删除或重命名本文件以避免被再次执行。
 */
require_once __DIR__ . '/includes/config.php';

$messages = [];
$err = null;

try {
    // 1. 不连库连接，CREATE DATABASE
    $dsn = sprintf('mysql:host=%s;port=%d;charset=utf8mb4', DB_HOST, DB_PORT);
    $pdo = new PDO($dsn, DB_USER, DB_PASS, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    ]);
    $pdo->exec("CREATE DATABASE IF NOT EXISTS `" . DB_NAME . "` "
             . "DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    $messages[] = "✓ 数据库 `" . DB_NAME . "` 已就绪";

    // 2. 切到目标库
    $pdo->exec("USE `" . DB_NAME . "`");

    // 3. 建表（直接 inline，避免依赖 schema.sql）
    $pdo->exec("CREATE TABLE IF NOT EXISTS `admins` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `username` VARCHAR(64) NOT NULL UNIQUE,
        `password_hash` VARCHAR(255) NOT NULL,
        `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `last_login_at` DATETIME NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='后台管理员'");
    $messages[] = "✓ 表 `admins` 已就绪";

    $pdo->exec("CREATE TABLE IF NOT EXISTS `licenses` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `account` VARCHAR(32) NOT NULL,
        `expiry_date` DATE NOT NULL,
        `license_code` TEXT NOT NULL,
        `xor_key` VARCHAR(64) NOT NULL,
        `product` VARCHAR(32) NOT NULL DEFAULT 'XAUUSD',
        `remark` VARCHAR(255) NULL,
        `created_by` VARCHAR(64) NOT NULL,
        `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uk_account_expiry_product` (`account`, `expiry_date`, `product`),
        KEY `idx_account` (`account`),
        KEY `idx_expiry` (`expiry_date`),
        KEY `idx_created_at` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='授权码生成记录'");
    $messages[] = "✓ 表 `licenses` 已就绪";

    // 为已存在的表补上唯一索引（幂等）
    $stmt = $pdo->query(
        "SELECT COUNT(*) FROM information_schema.STATISTICS
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME   = 'licenses'
           AND INDEX_NAME   = 'uk_account_expiry_product'"
    );
    if ((int)$stmt->fetchColumn() === 0) {
        // 补建唯一索引前，先清理表中的重复记录（保留 id 最小者）
        try {
            $dupBefore = (int)$pdo->query(
                "SELECT COUNT(*) FROM (
                     SELECT 1 FROM licenses
                     GROUP BY account, expiry_date, product
                     HAVING COUNT(*) > 1
                 ) t"
            )->fetchColumn();
            if ($dupBefore > 0) {
                $messages[] = "⚠ 检测到 $dupBefore 组 账号+有效期+产品 重复数据，正在清理……";
                $del = $pdo->exec(
                    "DELETE l1 FROM licenses l1
                     INNER JOIN licenses l2
                     WHERE l1.id > l2.id
                       AND l1.account     = l2.account
                       AND l1.expiry_date = l2.expiry_date
                       AND l1.product     = l2.product"
                );
                $messages[] = "✓ 已删除 $del 条重复记录（保留最早生成的一条）";
            }
        } catch (Throwable $e) {
            $messages[] = "⚠ 重复数据清理失败：" . htmlspecialchars($e->getMessage());
        }

        try {
            $pdo->exec("ALTER TABLE `licenses` ADD UNIQUE KEY `uk_account_expiry_product` (`account`, `expiry_date`, `product`)");
            $messages[] = "✓ 唯一索引 uk_account_expiry_product 已补建（去重）";
        } catch (Throwable $e) {
            $messages[] = "⚠ 唯一索引补建失败：" . htmlspecialchars($e->getMessage());
        }
    } else {
        $messages[] = "• 唯一索引 uk_account_expiry_product 已存在";
    }

    // 4. 写入默认管理员（已存在则跳过）
    $stmt = $pdo->prepare("SELECT id FROM admins WHERE username = ?");
    $stmt->execute([DEFAULT_ADMIN_USER]);
    if (!$stmt->fetchColumn()) {
        $hash = password_hash(DEFAULT_ADMIN_PASSWORD, PASSWORD_DEFAULT);
        $pdo->prepare("INSERT INTO admins(username, password_hash) VALUES (?, ?)")
            ->execute([DEFAULT_ADMIN_USER, $hash]);
        $messages[] = "✓ 默认管理员已创建：<b>" . htmlspecialchars(DEFAULT_ADMIN_USER)
                    . "</b> / <b>" . htmlspecialchars(DEFAULT_ADMIN_PASSWORD) . "</b>";
    } else {
        $messages[] = "• 管理员 " . htmlspecialchars(DEFAULT_ADMIN_USER) . " 已存在，跳过";
    }
} catch (Throwable $e) {
    $err = $e->getMessage();
}
?><!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>金貔貅后台 · 安装</title>
<style>
  body{font-family:'Microsoft YaHei',sans-serif;background:#0a0a0f;color:#e0e0e8;
       padding:60px 20px;line-height:1.8;}
  .box{max-width:640px;margin:0 auto;background:rgba(20,20,35,.85);
       border:1px solid rgba(212,167,69,.25);border-radius:14px;padding:36px;}
  h1{color:#d4a745;border-bottom:1px solid rgba(212,167,69,.3);padding-bottom:12px;}
  ul{list-style:none;padding:0;margin:18px 0;}
  li{padding:8px 0;border-bottom:1px dashed rgba(255,255,255,.08);}
  .err{background:rgba(224,64,64,.15);border:1px solid rgba(224,64,64,.4);
       padding:12px;border-radius:8px;color:#ff8080;}
  a{color:#d4a745;}
  .tip{font-size:13px;color:#a0a0b8;margin-top:20px;}
</style>
</head>
<body>
<div class="box">
  <h1>金貔貅 · 后台安装</h1>
  <?php if ($err): ?>
    <div class="err">✗ 安装失败：<?= htmlspecialchars($err) ?></div>
    <p class="tip">请检查 <code>includes/config.php</code> 中的 MySQL 连接信息，并确认 MySQL 服务正在运行。</p>
  <?php else: ?>
    <ul>
      <?php foreach ($messages as $m): ?>
        <li><?= $m ?></li>
      <?php endforeach; ?>
    </ul>
    <p>👉 现在前往 <a href="login.php">登录页</a></p>
    <p class="tip">⚠️ 出于安全考虑，安装完成后请删除本文件 <code>install.php</code>。</p>
  <?php endif; ?>
</div>
</body>
</html>
