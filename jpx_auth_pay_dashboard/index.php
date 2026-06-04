<?php
require_once __DIR__ . '/includes/business.php';
try {
    $stmt = db()->query("SELECT id, account_login, customer_name, expires_at
                         FROM accounts ORDER BY id DESC LIMIT 300");
    $accounts = $stmt->fetchAll();
} catch (Throwable $e) {
    $accounts = [];
    $installError = $e->getMessage();
}
?><!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>金貔貅账号续费</title>
<link rel="stylesheet" href="assets/css/app.css">
<script src="https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js"></script>
</head>
<body>
<header class="topbar"><div class="brand">金貔貅账号续费</div><nav class="nav"><a href="admin/login.php">管理员登录</a></nav></header>
<main class="wrap">
  <section class="panel">
    <h1>授权账号续费</h1>
    <p class="muted">每次续费 200 元，付款成功后自动延期 1 个月。未到期账号从当前到期日顺延，已过期账号从付款当天重新计算。</p>
    <?php if (!empty($installError)): ?>
      <div class="alert danger">数据库尚未安装或连接失败：<?= h($installError) ?>。请先访问 <a href="install.php">install.php</a>。</div>
    <?php endif; ?>
    <div class="toolbar"><div><label>搜索</label><input id="search" placeholder="账号 / 用户"></div></div>
    <table id="accountTable">
      <thead><tr><th>用户</th><th>交易账号</th><th>状态</th><th>到期时间</th><th>操作</th></tr></thead>
      <tbody>
      <?php foreach ($accounts as $a): $status = account_status($a['expires_at']); ?>
        <tr data-text="<?= h($a['customer_name'] . ' ' . $a['account_login']) ?>">
          <td><?= h($a['customer_name']) ?></td><td><?= h($a['account_login']) ?></td>
          <td><span class="status <?= h($status) ?>"><?= h($status) ?></span></td>
          <td><?= h($a['expires_at'] ?: '未付款') ?></td>
          <td><button class="btn primary" onclick="renew(<?= (int)$a['id'] ?>,'<?= h($a['account_login']) ?>')">扫码续费</button></td>
        </tr>
      <?php endforeach; ?>
      </tbody>
    </table>
  </section>
</main>
<div id="payModal" class="modal"><div class="modal-card">
  <h2>微信扫码支付</h2>
  <p id="payInfo" class="muted"></p>
  <div id="qrBox"></div>
  <p id="payMsg" class="muted"></p>
  <button class="btn" onclick="closePay()">关闭</button>
</div></div>
<script>
let timer = null;
document.getElementById('search').addEventListener('input', e => {
  const q = e.target.value.trim().toLowerCase();
  document.querySelectorAll('#accountTable tbody tr').forEach(tr => tr.style.display = tr.dataset.text.toLowerCase().includes(q) ? '' : 'none');
});
async function renew(id, account) {
  clearInterval(timer);
  const modal = document.getElementById('payModal');
  const qrBox = document.getElementById('qrBox');
  qrBox.innerHTML = '';
  document.getElementById('payInfo').textContent = account + ' 续费 200 元';
  document.getElementById('payMsg').textContent = '正在创建支付订单...';
  modal.classList.add('show');
  const body = new URLSearchParams({account_id: id});
  const res = await fetch('api/create_payment.php', {method:'POST', body});
  const data = await res.json();
  if (!data.ok) {
    document.getElementById('payMsg').textContent = data.msg || '创建订单失败';
    qrBox.innerHTML = '<div style="color:#111">无法生成二维码</div>';
    return;
  }
  new QRCode(qrBox, {text:data.code_url, width:210, height:210});
  document.getElementById('payMsg').textContent = '请使用微信扫码支付，支付成功后本窗口会自动更新。';
  timer = setInterval(async () => {
    const r = await fetch('api/payment_status.php?order_no=' + encodeURIComponent(data.order_no));
    const s = await r.json();
    if (s.paid) {
      clearInterval(timer);
      document.getElementById('payMsg').textContent = '支付成功，到期时间：' + s.expires_at;
      setTimeout(() => location.reload(), 1500);
    }
  }, 3000);
}
function closePay(){ clearInterval(timer); document.getElementById('payModal').classList.remove('show'); }
</script>
</body>
</html>
