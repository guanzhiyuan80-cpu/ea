<?php
require_once __DIR__ . '/../includes/business.php';
require_once __DIR__ . '/../includes/auth.php';
$admin = require_admin();

$q = trim($_GET['q'] ?? '');
$status = trim($_GET['status'] ?? '');
$dateFrom = trim($_GET['date_from'] ?? date('Y-m-d', strtotime('-30 days')));
$dateTo = trim($_GET['date_to'] ?? date('Y-m-d'));

$where = 'WHERE o.created_at >= ? AND o.created_at < DATE_ADD(?, INTERVAL 1 DAY)';
$params = [$dateFrom, $dateTo];
if ($q !== '') {
    $where .= ' AND (o.order_no LIKE ? OR a.account_login LIKE ? OR a.customer_name LIKE ? OR o.wx_transaction_id LIKE ?)';
    $like = '%' . $q . '%';
    array_push($params, $like, $like, $like, $like);
}
if ($status !== '' && in_array($status, ['pending', 'paid', 'failed', 'closed'], true)) {
    $where .= ' AND o.status = ?';
    $params[] = $status;
}

$sql = "SELECT o.*, a.account_login, a.customer_name, a.expires_at
        FROM renew_orders o
        LEFT JOIN accounts a ON a.id = o.account_id
        $where
        ORDER BY o.created_at DESC
        LIMIT 500";
$stmt = db()->prepare($sql);
$stmt->execute($params);
$orders = $stmt->fetchAll();

// 统计：用相同 where 条件
$kpiSql = "SELECT
            COUNT(*) AS total_count,
            SUM(o.status = 'paid') AS paid_count,
            SUM(o.status = 'pending') AS pending_count,
            SUM(o.status = 'failed') AS failed_count,
            IFNULL(SUM(CASE WHEN o.status = 'paid' THEN o.amount_yuan ELSE 0 END), 0) AS paid_amount
           FROM renew_orders o
           LEFT JOIN accounts a ON a.id = o.account_id
           $where";
$stmt = db()->prepare($kpiSql);
$stmt->execute($params);
$kpi = $stmt->fetch() ?: ['total_count' => 0, 'paid_count' => 0, 'pending_count' => 0, 'failed_count' => 0, 'paid_amount' => 0];

function order_status_label(string $s): string {
    return ['pending' => '待支付', 'paid' => '已支付', 'failed' => '失败', 'closed' => '已关闭'][$s] ?? $s;
}
?><!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>续费支付记录</title>
<link rel="icon" type="image/jpeg" href="../assets/img/favicon.jpg?v=20260729-1">
<link rel="stylesheet" href="../assets/css/app.css?v=20260729-1">
</head>
<body>
<header class="topbar"><div class="brand">青鸾授权续费系统</div><nav class="nav">
  <a href="accounts.php">账号管理</a>
  <a href="dashboard.php">盈亏大屏</a>
  <a class="active" href="orders.php">续费记录</a>
  <a href="../index.php">游客续费页</a>
  <a href="logout.php">退出</a>
</nav></header>
<main class="wrap">
  <section class="panel">
    <h2>续费支付记录</h2>
    <form class="toolbar" method="get">
      <div><label>关键词</label><input name="q" value="<?= h($q) ?>" placeholder="订单号 / 账号 / 用户 / 微信交易号"></div>
      <div><label>状态</label><select name="status">
        <option value="">全部</option>
        <option value="paid" <?= $status==='paid'?'selected':'' ?>>已支付</option>
        <option value="pending" <?= $status==='pending'?'selected':'' ?>>待支付</option>
        <option value="failed" <?= $status==='failed'?'selected':'' ?>>失败</option>
        <option value="closed" <?= $status==='closed'?'selected':'' ?>>已关闭</option>
      </select></div>
      <div><label>开始</label><input type="date" name="date_from" value="<?= h($dateFrom) ?>"></div>
      <div><label>结束</label><input type="date" name="date_to" value="<?= h($dateTo) ?>"></div>
      <button class="btn primary">筛选</button>
    </form>
    <div class="grid cols-4" style="margin-top:14px">
      <div class="kpi"><div class="muted">订单总数</div><div class="num"><?= (int)$kpi['total_count'] ?></div></div>
      <div class="kpi"><div class="muted">已支付</div><div class="num" style="color:var(--green)"><?= (int)$kpi['paid_count'] ?></div></div>
      <div class="kpi"><div class="muted">待支付</div><div class="num" style="color:var(--gold)"><?= (int)$kpi['pending_count'] ?></div></div>
      <div class="kpi"><div class="muted">已收款合计</div><div class="num" style="color:var(--gold2)">¥<?= number_format((float)$kpi['paid_amount'], 2) ?></div></div>
    </div>
  </section>
  <section class="panel" style="margin-top:18px">
    <table>
      <thead><tr>
        <th>订单号</th><th>用户</th><th>账号</th><th>金额</th><th>月数</th><th>状态</th>
        <th>创建时间</th><th>支付时间</th><th>微信交易号</th><th>到期</th>
      </tr></thead>
      <tbody>
      <?php if (!$orders): ?>
        <tr><td colspan="10" style="text-align:center;color:var(--muted);padding:30px">该范围内没有订单</td></tr>
      <?php else: foreach ($orders as $o): ?>
        <tr>
          <td class="code"><?= h($o['order_no']) ?></td>
          <td><?= h($o['customer_name'] ?? '-') ?></td>
          <td><?= h($o['account_login'] ?? '-') ?></td>
          <td>¥<?= number_format((float)$o['amount_yuan'], 2) ?></td>
          <td><?= (int)$o['months'] ?></td>
          <td><span class="status <?= h($o['status']) === 'paid' ? 'active' : (h($o['status']) === 'pending' ? 'warning' : 'expired') ?>"><?= h(order_status_label($o['status'])) ?></span></td>
          <td><?= h($o['created_at']) ?></td>
          <td><?= h($o['paid_at'] ?: '-') ?></td>
          <td class="code" style="max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="<?= h($o['wx_transaction_id'] ?: '') ?>"><?= h($o['wx_transaction_id'] ?: '-') ?></td>
          <td><?= h($o['expires_at'] ?: '-') ?></td>
        </tr>
      <?php endforeach; endif; ?>
      </tbody>
    </table>
    <p class="muted" style="margin-top:10px">最多展示最近 500 条记录，请用日期范围或关键词筛选。</p>
  </section>
</main>
</body></html>
