<?php
require_once __DIR__ . '/../includes/business.php';
require_once __DIR__ . '/../includes/auth.php';
require_admin();

$customer = trim($_GET['customer'] ?? '');
$account = trim($_GET['account'] ?? '');
$dateFrom = trim($_GET['date_from'] ?? date('Y-m-d', strtotime('-30 days')));
$dateTo = trim($_GET['date_to'] ?? date('Y-m-d'));

$where = 'WHERE report_time >= ? AND report_time < DATE_ADD(?, INTERVAL 1 DAY)';
$params = [$dateFrom, $dateTo];
if ($customer !== '') { $where .= ' AND customer_name = ?'; $params[] = $customer; }
if ($account !== '') { $where .= ' AND account_login = ?'; $params[] = $account; }

$customers = db()->query("SELECT DISTINCT customer_name FROM accounts ORDER BY customer_name")->fetchAll();
$accounts = db()->query("SELECT DISTINCT account_login FROM accounts ORDER BY account_login")->fetchAll();

$stmt = db()->prepare("SELECT COUNT(DISTINCT account_login, server_name) AS account_count,
                              IFNULL(SUM(realized_profit),0) AS realized_sum,
                              IFNULL(AVG(equity),0) AS avg_equity,
                              IFNULL(SUM(floating_profit),0) AS floating_sum
                       FROM trade_reports $where");
$stmt->execute($params);
$kpi = $stmt->fetch();

$stmt = db()->prepare("SELECT DATE(report_time) AS d, SUM(realized_profit) AS realized, SUM(floating_profit) AS floating
                       FROM trade_reports $where GROUP BY DATE(report_time) ORDER BY d");
$stmt->execute($params);
$daily = $stmt->fetchAll();

$stmt = db()->prepare("SELECT customer_name, account_login, server_name,
                              MAX(report_time) AS last_time,
                              SUBSTRING_INDEX(GROUP_CONCAT(balance ORDER BY report_time DESC), ',', 1) AS balance,
                              SUBSTRING_INDEX(GROUP_CONCAT(equity ORDER BY report_time DESC), ',', 1) AS equity,
                              SUBSTRING_INDEX(GROUP_CONCAT(floating_profit ORDER BY report_time DESC), ',', 1) AS floating_profit,
                              SUBSTRING_INDEX(GROUP_CONCAT(open_positions ORDER BY report_time DESC), ',', 1) AS open_positions
                       FROM trade_reports $where
                       GROUP BY customer_name, account_login, server_name
                       ORDER BY customer_name, account_login");
$stmt->execute($params);
$latest = $stmt->fetchAll();
?><!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>盈亏大屏</title><link rel="stylesheet" href="../assets/css/app.css"><script src="https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js"></script></head>
<body>
<header class="topbar"><div class="brand">金貔貅盈亏大屏</div><nav class="nav">
  <a href="accounts.php">账号管理</a><a class="active" href="dashboard.php">盈亏大屏</a><a href="logout.php">退出</a>
</nav></header>
<main class="wrap">
  <section class="panel">
    <form class="toolbar" method="get">
      <div><label>用户</label><select name="customer"><option value="">全部</option><?php foreach($customers as $c): ?><option <?= $customer===$c['customer_name']?'selected':'' ?>><?= h($c['customer_name']) ?></option><?php endforeach; ?></select></div>
      <div><label>账号</label><select name="account"><option value="">全部</option><?php foreach($accounts as $a): ?><option <?= $account===$a['account_login']?'selected':'' ?>><?= h($a['account_login']) ?></option><?php endforeach; ?></select></div>
      <div><label>开始</label><input type="date" name="date_from" value="<?= h($dateFrom) ?>"></div>
      <div><label>结束</label><input type="date" name="date_to" value="<?= h($dateTo) ?>"></div>
      <button class="btn primary">筛选</button>
    </form>
    <div class="grid cols-4">
      <div class="kpi"><div class="muted">账号数</div><div class="num"><?= (int)$kpi['account_count'] ?></div></div>
      <div class="kpi"><div class="muted">已实现盈亏</div><div class="num"><?= number_format((float)$kpi['realized_sum'],2) ?></div></div>
      <div class="kpi"><div class="muted">浮动盈亏合计</div><div class="num"><?= number_format((float)$kpi['floating_sum'],2) ?></div></div>
      <div class="kpi"><div class="muted">平均净值</div><div class="num"><?= number_format((float)$kpi['avg_equity'],2) ?></div></div>
    </div>
  </section>
  <section class="grid" style="margin-top:18px;grid-template-columns:1fr 1fr">
    <div class="chart" id="dailyChart"></div>
    <div class="chart" id="floatingChart"></div>
  </section>
  <section class="panel" style="margin-top:18px">
    <h2>账户最新快照</h2>
    <table><thead><tr><th>用户</th><th>账号</th><th>服务器</th><th>余额</th><th>净值</th><th>浮盈亏</th><th>持仓</th><th>最后上报</th></tr></thead><tbody>
    <?php foreach($latest as $r): ?><tr>
      <td><?= h($r['customer_name']) ?></td><td><?= h($r['account_login']) ?></td><td><?= h($r['server_name']) ?></td>
      <td><?= number_format((float)$r['balance'],2) ?></td><td><?= number_format((float)$r['equity'],2) ?></td>
      <td><?= number_format((float)$r['floating_profit'],2) ?></td><td><?= (int)$r['open_positions'] ?></td><td><?= h($r['last_time']) ?></td>
    </tr><?php endforeach; ?>
    </tbody></table>
  </section>
</main>
<script>
const daily = <?= json_encode($daily, JSON_UNESCAPED_UNICODE) ?>;
const days = daily.map(x=>x.d);
echarts.init(document.getElementById('dailyChart')).setOption({
  title:{text:'每日已实现盈亏',textStyle:{color:'#eef3ff'}},tooltip:{trigger:'axis'},xAxis:{type:'category',data:days,axisLabel:{color:'#9da9c3'}},yAxis:{type:'value',axisLabel:{color:'#9da9c3'}},
  series:[{type:'bar',data:daily.map(x=>Number(x.realized||0)),itemStyle:{color:'#38d07f'}}]
});
echarts.init(document.getElementById('floatingChart')).setOption({
  title:{text:'每日浮动盈亏',textStyle:{color:'#eef3ff'}},tooltip:{trigger:'axis'},xAxis:{type:'category',data:days,axisLabel:{color:'#9da9c3'}},yAxis:{type:'value',axisLabel:{color:'#9da9c3'}},
  series:[{type:'line',smooth:true,data:daily.map(x=>Number(x.floating||0)),lineStyle:{color:'#3aa7ff'},areaStyle:{color:'rgba(58,167,255,.18)'}}]
});
</script>
</body></html>
