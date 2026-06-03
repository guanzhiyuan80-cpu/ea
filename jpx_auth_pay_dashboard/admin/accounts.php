<?php
require_once __DIR__ . '/../includes/business.php';
require_once __DIR__ . '/../includes/auth.php';
$admin = require_admin();
$msg = '';
$err = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $account = trim($_POST['account_login'] ?? '');
    $server = trim($_POST['server_name'] ?? '');
    $customer = trim($_POST['customer_name'] ?? '');
    $note = trim($_POST['admin_note'] ?? '');
    if ($account === '' || $server === '' || $customer === '') {
        $err = '账号、服务器、用户都必须填写';
    } elseif (!ctype_digit($account)) {
        $err = '交易账号必须是数字';
    } else {
        try {
            $stmt = db()->prepare("INSERT INTO accounts(account_login, server_name, customer_name, product, admin_note, created_by)
                                   VALUES(?, ?, ?, ?, ?, ?)");
            $stmt->execute([$account, $server, $customer, DEFAULT_PRODUCT, $note !== '' ? $note : null, $admin['username']]);
            $msg = '账号添加成功，付款后才会生成授权码';
        } catch (PDOException $e) {
            if (strpos($e->getMessage(), '1062') !== false) $err = '该交易账号 + 服务器已存在，禁止重复添加';
            else $err = '添加失败：' . $e->getMessage();
        }
    }
}

$q = trim($_GET['q'] ?? '');
$where = 'WHERE 1=1';
$params = [];
if ($q !== '') {
    $where .= ' AND (account_login LIKE ? OR server_name LIKE ? OR customer_name LIKE ? OR admin_note LIKE ?)';
    $like = '%' . $q . '%';
    $params = [$like, $like, $like, $like];
}
$stmt = db()->prepare("SELECT * FROM accounts $where ORDER BY id DESC");
$stmt->execute($params);
$accounts = $stmt->fetchAll();
?><!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>授权账号管理</title><link rel="stylesheet" href="../assets/css/app.css"></head>
<body>
<header class="topbar"><div class="brand">金貔貅授权续费系统</div><nav class="nav">
  <a class="active" href="accounts.php">账号管理</a><a href="dashboard.php">盈亏大屏</a><a href="../index.php">游客续费页</a><a href="logout.php">退出</a>
</nav></header>
<main class="wrap">
  <section class="panel">
    <h2>添加账号</h2>
    <?php if ($msg): ?><div class="alert ok"><?= h($msg) ?></div><?php endif; ?>
    <?php if ($err): ?><div class="alert danger"><?= h($err) ?></div><?php endif; ?>
    <form class="form-grid" method="post">
      <div><label>交易账号</label><input name="account_login" required></div>
      <div><label>服务器</label><input name="server_name" required></div>
      <div><label>用户</label><input name="customer_name" required placeholder="例如：张三"></div>
      <div><label>备注（仅管理员可见）</label><input name="admin_note"></div>
      <button class="btn primary">添加</button>
    </form>
  </section>
  <section class="panel" style="margin-top:18px">
    <form class="toolbar" method="get"><div><label>搜索</label><input name="q" value="<?= h($q) ?>" placeholder="账号/服务器/用户/备注"></div><button class="btn">搜索</button></form>
    <table>
      <thead><tr><th>ID</th><th>用户</th><th>账号</th><th>服务器</th><th>状态</th><th>到期时间</th><th>授权码</th><th>备注</th><th>心跳</th></tr></thead>
      <tbody>
      <?php foreach ($accounts as $a): $status = account_status($a['expires_at'], !empty($a['license_code'])); ?>
        <tr>
          <td><?= (int)$a['id'] ?></td><td><?= h($a['customer_name']) ?></td><td><?= h($a['account_login']) ?></td><td><?= h($a['server_name']) ?></td>
          <td><span class="status <?= h($status) ?>"><?= h($status) ?></span></td>
          <td><?= h($a['expires_at'] ?: '-') ?></td>
          <td class="code"><?= h($a['license_code'] ?: '付款后生成') ?></td>
          <td><?= nl2br(h($a['admin_note'])) ?></td>
          <td><?= h($a['last_heartbeat_at'] ?: '-') ?></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </section>
</main>
</body></html>
