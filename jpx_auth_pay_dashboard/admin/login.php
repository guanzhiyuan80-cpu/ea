<?php
require_once __DIR__ . '/../includes/business.php';
require_once __DIR__ . '/../includes/auth.php';

$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = trim($_POST['username'] ?? '');
    $password = (string)($_POST['password'] ?? '');
    $stmt = db()->prepare("SELECT * FROM admins WHERE username = ? LIMIT 1");
    $stmt->execute([$username]);
    $admin = $stmt->fetch();
    if ($admin && password_verify($password, $admin['password_hash'])) {
        login_admin((int)$admin['id'], $admin['username']);
        db()->prepare("UPDATE admins SET last_login_at = NOW() WHERE id = ?")->execute([(int)$admin['id']]);
        header('Location: accounts.php');
        exit;
    }
    $error = '账号或密码错误';
}
?><!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>管理员登录</title><link rel="icon" type="image/jpeg" href="../assets/img/favicon.jpg?v=20260729-1"><link rel="stylesheet" href="../assets/css/app.css?v=20260729-1"></head>
<body class="page-center">
<main class="panel narrow">
  <h1>青鸾后台</h1>
  <?php if ($error): ?><div class="alert danger"><?= h($error) ?></div><?php endif; ?>
  <form method="post">
    <label>管理员账号</label><input name="username" required autofocus>
    <label style="margin-top:12px">密码</label><input name="password" type="password" required>
    <button class="btn primary" style="width:100%;margin-top:18px">登录</button>
  </form>
  <p class="muted"><a href="../index.php">返回续费列表</a></p>
</main>
</body></html>
