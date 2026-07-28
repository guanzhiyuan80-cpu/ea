<?php
require_once __DIR__ . '/config/config.php';

$messages = [];
$error = null;

try {
    $pdo = new PDO(sprintf('mysql:host=%s;port=%d;charset=utf8mb4', DB_HOST, DB_PORT), DB_USER, DB_PASS, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    $pdo->exec("CREATE DATABASE IF NOT EXISTS `" . DB_NAME . "` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
    $pdo->exec("USE `" . DB_NAME . "`");
    $sql = file_get_contents(__DIR__ . '/schema.sql');
    foreach (array_filter(array_map('trim', explode(';', $sql))) as $stmt) {
        if ($stmt !== '') $pdo->exec($stmt);
    }
    $messages[] = '数据库和数据表已准备完成';

    $stmt = $pdo->prepare("SELECT id FROM admins WHERE username = ?");
    $stmt->execute([DEFAULT_ADMIN_USER]);
    if (!$stmt->fetchColumn()) {
        $hash = password_hash(DEFAULT_ADMIN_PASSWORD, PASSWORD_DEFAULT);
        $pdo->prepare("INSERT INTO admins(username, password_hash) VALUES(?, ?)")
            ->execute([DEFAULT_ADMIN_USER, $hash]);
        $messages[] = '默认管理员已创建：admin / admin123';
    } else {
        $messages[] = '默认管理员已存在，跳过创建';
    }
} catch (Throwable $e) {
    $error = $e->getMessage();
}
?><!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>青鸾授权续费系统安装</title>
<link rel="icon" type="image/jpeg" href="assets/img/favicon.jpg?v=20260729-1">
<link rel="stylesheet" href="assets/css/app.css?v=20260729-1">
</head>
<body class="page-center">
<main class="panel narrow">
  <h1>系统安装</h1>
  <?php if ($error): ?>
    <div class="alert danger">安装失败：<?= htmlspecialchars($error) ?></div>
  <?php else: ?>
    <?php foreach ($messages as $m): ?><div class="alert ok"><?= htmlspecialchars($m) ?></div><?php endforeach; ?>
    <p class="muted">安装完成后建议删除或改名 <code>install.php</code>，并立即修改默认管理员密码。</p>
    <a class="btn primary" href="admin/login.php">进入管理员登录</a>
  <?php endif; ?>
</main>
</body>
</html>
