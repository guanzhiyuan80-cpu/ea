<?php
require_once __DIR__ . '/includes/business.php';
$installError = null;
try {
    db()->query("SELECT 1");
} catch (Throwable $e) {
    $installError = $e->getMessage();
}
?><!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>青鸾账号续费</title>
<link rel="icon" type="image/jpeg" href="assets/img/favicon.jpg?v=20260729-1">
<link rel="stylesheet" href="assets/css/app.css?v=20260729-1">
<script src="https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js"></script>
</head>
<body>
<header class="topbar">
  <div class="brand">青鸾账号续费</div>
  <nav class="nav"><a href="admin/login.php">管理员登录</a></nav>
</header>

<main class="wrap renew-wrap">
  <section class="panel">
    <h1>账号续费</h1>
    <p class="muted">输入交易账号或用户名称搜索账号。每次续费 200 元，付款成功后自动延期 1 个月。</p>
    <?php if ($installError): ?>
      <div class="alert danger">数据库尚未安装或连接失败：<?= h($installError) ?>。请先访问 <a href="install.php">install.php</a>。</div>
    <?php endif; ?>

    <div class="renew-search">
      <label>交易账号 / 用户</label>
      <div class="search-line">
        <input id="search" inputmode="text" autocomplete="off" placeholder="请输入交易账号或用户名称">
        <button class="btn primary" onclick="searchAccounts()">搜索</button>
      </div>
    </div>

    <div id="stateText" class="empty-state">为了保护账号隐私，默认不展示全部账户。请先搜索。</div>
    <div id="results" class="renew-results"></div>
  </section>
</main>

<div id="payModal" class="modal">
  <div class="modal-card">
    <h2>微信扫码支付</h2>
    <p id="payInfo" class="muted"></p>
    <div id="qrBox"></div>
    <p id="payMsg" class="muted"></p>
    <button class="btn" onclick="closePay()">关闭</button>
  </div>
</div>

<div id="wechatGuide" class="wechat-guide">
  <div class="wechat-guide-arrow">↗</div>
  <div class="wechat-guide-tip">请点击右上角 <b>⋯</b><br>选择「<b>在浏览器中打开</b>」</div>
  <div class="wechat-guide-sub">由于微信内置浏览器限制，请在外部浏览器中完成微信扫码支付</div>
  <button class="btn primary" onclick="closeWxGuide()" style="margin-top:18px;min-width:160px">我知道了</button>
</div>

<script>
let timer = null;
let searchTimer = null;
const isWeChat = /MicroMessenger/i.test(navigator.userAgent);

document.getElementById('search').addEventListener('input', () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(searchAccounts, 350);
});
document.getElementById('search').addEventListener('keydown', e => {
  if (e.key === 'Enter') searchAccounts();
});

function statusText(status) {
  return {active:'已授权', warning:'即将到期', expired:'已过期', unpaid:'未付款'}[status] || status;
}

async function searchAccounts() {
  const q = document.getElementById('search').value.trim();
  const state = document.getElementById('stateText');
  const box = document.getElementById('results');
  box.innerHTML = '';
  if (!q) {
    state.textContent = '为了保护账号隐私，默认不展示全部账户。请先搜索。';
    state.style.display = 'block';
    return;
  }
  state.textContent = '正在搜索...';
  state.style.display = 'block';
  const res = await fetch('api/accounts.php?q=' + encodeURIComponent(q));
  const data = await res.json();
  if (!data.ok) {
    state.textContent = data.msg || '搜索失败';
    return;
  }
  if (!data.items.length) {
    state.textContent = '没有找到匹配账号，请核对交易账号或用户名称。';
    return;
  }
  state.style.display = 'none';
  box.innerHTML = data.items.map(item => `
    <article class="renew-card">
      <div>
        <div class="renew-user">${escapeHtml(item.customer_name)}</div>
        <div class="renew-account">${escapeHtml(item.account_login)}</div>
      </div>
      <div class="renew-meta">
        <span class="status ${escapeHtml(item.status)}">${statusText(item.status)}</span>
        <span>到期：${escapeHtml(item.expires_at || '未付款')}</span>
      </div>
      <button class="btn primary" onclick="renew(${Number(item.id)}, '${escapeAttr(item.account_login)}')">续费 200 元</button>
    </article>
  `).join('');
}

async function renew(id, account) {
  clearInterval(timer);

  // 微信内置浏览器不支持 NATIVE 扫码跳转，引导用户去外部浏览器
  if (isWeChat) {
    showWxGuide();
    return;
  }

  const body = new URLSearchParams({account_id: id});
  openPayModal(account, '正在创建支付订单...');

  const res = await fetch('api/create_payment.php', {method:'POST', body});
  const data = await res.json();
  if (!data.ok) {
    showPayError(data.msg || '创建订单失败');
    return;
  }

  showQr(account, data);
}

function showWxGuide() {
  document.getElementById('wechatGuide').classList.add('show');
}
function closeWxGuide() {
  document.getElementById('wechatGuide').classList.remove('show');
}

function openPayModal(account, msg) {
  document.getElementById('qrBox').innerHTML = '';
  document.getElementById('payInfo').textContent = account + ' 续费 200 元';
  document.getElementById('payMsg').textContent = msg;
  document.getElementById('payModal').classList.add('show');
}

function showQr(account, data) {
  openPayModal(account, '请使用微信扫码支付，支付成功后本窗口会自动更新。');
  new QRCode(document.getElementById('qrBox'), {text:data.code_url, width:210, height:210});
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

function showPayError(msg) {
  document.getElementById('payMsg').textContent = msg;
  document.getElementById('qrBox').innerHTML = '<div style="color:#111">无法生成支付二维码</div>';
}

function closePay() {
  clearInterval(timer);
  document.getElementById('payModal').classList.remove('show');
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, s => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[s]));
}

function escapeAttr(value) {
  return escapeHtml(value).replace(/\\/g, '\\\\');
}
</script>
</body>
</html>
