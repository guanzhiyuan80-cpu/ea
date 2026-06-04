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
if ($customer !== '') {
    $stmt = db()->prepare("SELECT DISTINCT account_login FROM accounts WHERE customer_name = ? ORDER BY account_login");
    $stmt->execute([$customer]);
    $accounts = $stmt->fetchAll();
} else {
    $accounts = db()->query("SELECT DISTINCT account_login FROM accounts ORDER BY account_login")->fetchAll();
}

$latestSql = "SELECT tr.customer_name, tr.account_login, tr.report_time AS last_time,
                     tr.balance, tr.equity, tr.floating_profit, tr.realized_profit, tr.open_positions
              FROM trade_reports tr
              INNER JOIN (
                  SELECT account_login, MAX(report_time) AS last_time
                  FROM trade_reports $where
                  GROUP BY account_login
              ) x ON x.account_login = tr.account_login AND x.last_time = tr.report_time";

$stmt = db()->prepare("SELECT COUNT(*) AS account_count,
                              IFNULL(SUM(realized_profit),0) AS realized_sum,
                              IFNULL(SUM(balance),0) AS balance_sum,
                              IFNULL(SUM(floating_profit),0) AS floating_sum
                       FROM ($latestSql) latest_rows");
$stmt->execute($params);
$kpi = $stmt->fetch();

$dailySql = "SELECT tr.customer_name, tr.account_login, DATE(tr.report_time) AS d,
                    tr.realized_profit, tr.floating_profit
             FROM trade_reports tr
             INNER JOIN (
                 SELECT account_login, DATE(report_time) AS d, MAX(report_time) AS last_time
                 FROM trade_reports $where
                 GROUP BY account_login, DATE(report_time)
             ) x ON x.account_login = tr.account_login
                AND x.d = DATE(tr.report_time)
                AND x.last_time = tr.report_time";

$stmt = db()->prepare("SELECT d, IFNULL(SUM(realized_profit),0) AS realized, IFNULL(SUM(floating_profit),0) AS floating
                       FROM ($dailySql) daily_rows GROUP BY d ORDER BY d");
$stmt->execute($params);
$daily = $stmt->fetchAll();
$kpi['realized_sum'] = 0.0;
foreach ($daily as $row) {
    $kpi['realized_sum'] += (float)$row['realized'];
}

$stmt = db()->prepare("$latestSql ORDER BY customer_name, account_login");
$stmt->execute($params);
$latest = $stmt->fetchAll();

$groupTitle = '';
$groupLabels = [];
$groupRealized = [];
$groupFloating = [];
if ($account !== '') {
    $groupTitle = '账号盈亏走势：' . $account;
    foreach ($daily as $row) {
        $groupLabels[] = $row['d'];
        $groupRealized[] = round((float)$row['realized'], 2);
        $groupFloating[] = round((float)$row['floating'], 2);
    }
} else {
    $groupKey = $customer !== '' ? 'account_login' : 'customer_name';
    $groupTitle = $customer !== '' ? '账号盈亏对比' : '用户盈亏对比';
    $stmt = db()->prepare("SELECT $groupKey AS label, IFNULL(SUM(realized_profit),0) AS realized
                           FROM ($dailySql) daily_rows GROUP BY $groupKey ORDER BY $groupKey");
    $stmt->execute($params);
    $realizedByLabel = [];
    foreach ($stmt->fetchAll() as $row) {
        $label = (string)$row['label'];
        $realizedByLabel[$label] = (float)$row['realized'];
    }
    $stmt = db()->prepare("SELECT $groupKey AS label, IFNULL(SUM(floating_profit),0) AS floating
                           FROM ($latestSql) latest_rows GROUP BY $groupKey ORDER BY $groupKey");
    $stmt->execute($params);
    foreach ($stmt->fetchAll() as $row) {
        $label = (string)$row['label'];
        $groupLabels[] = $label;
        $groupRealized[] = round($realizedByLabel[$label] ?? 0.0, 2);
        $groupFloating[] = round((float)$row['floating'], 2);
        unset($realizedByLabel[$label]);
    }
    foreach ($realizedByLabel as $label => $value) {
        $groupLabels[] = $label;
        $groupRealized[] = round((float)$value, 2);
        $groupFloating[] = 0.0;
    }
}
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
      <div><label>用户</label><select name="customer" id="customerSelect"><option value="">全部</option><?php foreach($customers as $c): ?><option <?= $customer===$c['customer_name']?'selected':'' ?>><?= h($c['customer_name']) ?></option><?php endforeach; ?></select></div>
      <div><label>账号</label><select name="account"><option value="">全部</option><?php foreach($accounts as $a): ?><option <?= $account===$a['account_login']?'selected':'' ?>><?= h($a['account_login']) ?></option><?php endforeach; ?></select></div>
      <div><label>开始</label><input type="date" name="date_from" value="<?= h($dateFrom) ?>"></div>
      <div><label>结束</label><input type="date" name="date_to" value="<?= h($dateTo) ?>"></div>
      <button class="btn primary">筛选</button>
    </form>
    <div class="grid cols-4">
      <div class="kpi"><div class="muted">账号数</div><div class="num"><?= (int)$kpi['account_count'] ?></div></div>
      <div class="kpi"><div class="muted">已实现盈亏</div><div class="num"><?= number_format((float)$kpi['realized_sum'],2) ?></div></div>
      <div class="kpi"><div class="muted">浮动盈亏合计</div><div class="num"><?= number_format((float)$kpi['floating_sum'],2) ?></div></div>
      <div class="kpi"><div class="muted">真实余额合计</div><div class="num"><?= number_format((float)$kpi['balance_sum'],2) ?></div></div>
    </div>
  </section>
  <section class="panel" style="margin-top:18px">
    <h2><?= h($groupTitle) ?></h2>
    <div class="chart chart-large" id="groupChart"></div>
  </section>
  <section class="grid" style="margin-top:18px;grid-template-columns:1fr 1fr">
    <div class="chart" id="dailyChart"></div>
    <div class="chart" id="floatingChart"></div>
  </section>
  <section class="panel" style="margin-top:18px">
    <h2>账户最新快照</h2>
    <table><thead><tr><th>用户</th><th>账号</th><th>余额</th><th>净值</th><th>浮盈亏</th><th>持仓</th><th>最后上报</th></tr></thead><tbody>
    <?php foreach($latest as $r): ?><tr>
      <td><?= h($r['customer_name']) ?></td><td><?= h($r['account_login']) ?></td>
      <td><?= number_format((float)$r['balance'],2) ?></td><td><?= number_format((float)$r['equity'],2) ?></td>
      <td><?= number_format((float)$r['floating_profit'],2) ?></td><td><?= (int)$r['open_positions'] ?></td><td><?= h($r['last_time']) ?></td>
    </tr><?php endforeach; ?>
    </tbody></table>
  </section>
</main>
<script>
const daily = <?= json_encode($daily, JSON_UNESCAPED_UNICODE) ?>;
const groupLabels = <?= json_encode($groupLabels, JSON_UNESCAPED_UNICODE) ?>;
const groupRealized = <?= json_encode($groupRealized, JSON_UNESCAPED_UNICODE) ?>;
const groupFloating = <?= json_encode($groupFloating, JSON_UNESCAPED_UNICODE) ?>;
const groupTitle = <?= json_encode($groupTitle, JSON_UNESCAPED_UNICODE) ?>;
document.getElementById('customerSelect')?.addEventListener('change', e => {
  const form = e.target.form;
  if (form?.account) form.account.value = '';
  form?.submit();
});
echarts.init(document.getElementById('groupChart')).setOption({
  title:{text:groupTitle,textStyle:{color:'#eef3ff'}},
  tooltip:{trigger:'axis'},
  legend:{top:28,textStyle:{color:'#9da9c3'},data:['已实现盈亏','浮动盈亏']},
  grid:{top:72,left:58,right:32,bottom:56},
  xAxis:{type:'category',data:groupLabels,axisLabel:{color:'#9da9c3',interval:0,rotate:groupLabels.length>8?28:0}},
  yAxis:{type:'value',axisLabel:{color:'#9da9c3'}},
  series:[
    {name:'已实现盈亏',type:'bar',data:groupRealized,itemStyle:{color:'#38d07f'}},
    {name:'浮动盈亏',type:'bar',data:groupFloating,itemStyle:{color:'#3aa7ff'}}
  ]
});
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
