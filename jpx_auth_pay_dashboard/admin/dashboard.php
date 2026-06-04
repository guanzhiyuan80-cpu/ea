<?php
require_once __DIR__ . '/../includes/business.php';
require_once __DIR__ . '/../includes/auth.php';
require_admin();

$customer = trim($_GET['customer'] ?? '');
$account = trim($_GET['account'] ?? '');
$dateFrom = trim($_GET['date_from'] ?? date('Y-m-d'));
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

// 今日已实现盈亏：按账号取今日（北京时间）最后一条快照的 realized_profit
$stmt = db()->prepare("SELECT tr.account_login, tr.realized_profit AS today_realized
                       FROM trade_reports tr
                       INNER JOIN (
                           SELECT account_login, MAX(report_time) AS lt
                           FROM trade_reports
                           WHERE DATE(report_time) = CURDATE()
                           GROUP BY account_login
                       ) m ON m.account_login = tr.account_login AND m.lt = tr.report_time");
$stmt->execute();
$todayRealizedMap = [];
foreach ($stmt->fetchAll() as $row) {
    $todayRealizedMap[$row['account_login']] = (float)$row['today_realized'];
}

// 仅趋势图专用：最近 30 天每日已实现/浮动盈亏（不受 date_from/date_to 影响，仍受 customer/account 筛选影响）
$trendWhere = 'WHERE report_time >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)';
$trendParams = [];
if ($customer !== '') { $trendWhere .= ' AND customer_name = ?'; $trendParams[] = $customer; }
if ($account !== '') { $trendWhere .= ' AND account_login = ?'; $trendParams[] = $account; }

$trendSql = "SELECT tr.account_login, DATE(tr.report_time) AS d,
                    tr.realized_profit, tr.floating_profit
             FROM trade_reports tr
             INNER JOIN (
                 SELECT account_login, DATE(report_time) AS d, MAX(report_time) AS last_time
                 FROM trade_reports $trendWhere
                 GROUP BY account_login, DATE(report_time)
             ) x ON x.account_login = tr.account_login
                AND x.d = DATE(tr.report_time)
                AND x.last_time = tr.report_time";
$stmt = db()->prepare("SELECT d, IFNULL(SUM(realized_profit),0) AS realized, IFNULL(SUM(floating_profit),0) AS floating
                       FROM ($trendSql) tr_rows GROUP BY d ORDER BY d");
$stmt->execute($trendParams);
$dailyTrendRaw = $stmt->fetchAll();

// 补全近 30 天日期序列（缺失日补 0），避免单点柱被边距吏掉
$dailyTrendMap = [];
foreach ($dailyTrendRaw as $row) { $dailyTrendMap[$row['d']] = $row; }
$dailyTrend = [];
for ($i = 29; $i >= 0; $i--) {
    $d = date('Y-m-d', strtotime("-{$i} days"));
    $dailyTrend[] = [
        'd' => $d,
        'realized' => isset($dailyTrendMap[$d]) ? (float)$dailyTrendMap[$d]['realized'] : 0.0,
        'floating' => isset($dailyTrendMap[$d]) ? (float)$dailyTrendMap[$d]['floating'] : 0.0,
    ];
}

// 账户最新快照按今日已实现盈亏降序排列（未上报账号排在末尾）
usort($latest, function ($a, $b) use ($todayRealizedMap) {
    $aHas = isset($todayRealizedMap[$a['account_login']]);
    $bHas = isset($todayRealizedMap[$b['account_login']]);
    if ($aHas && !$bHas) return -1;
    if (!$aHas && $bHas) return 1;
    if (!$aHas && !$bHas) {
        return strcmp((string)$a['account_login'], (string)$b['account_login']);
    }
    $av = $todayRealizedMap[$a['account_login']];
    $bv = $todayRealizedMap[$b['account_login']];
    if ($av == $bv) return strcmp((string)$a['account_login'], (string)$b['account_login']);
    return $av < $bv ? 1 : -1;
});

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
function pnl_class($value): string {
    $num = (float)$value;
    if ($num > 0) return 'pos';
    if ($num < 0) return 'neg';
    return 'flat';
}
function ea_status_info(?string $lastTime): array {
    if (!$lastTime) {
        return ['offline', '异常', '无心跳'];
    }
    $ts = strtotime($lastTime);
    if (!$ts) {
        return ['offline', '异常', '时间异常'];
    }
    $age = time() - $ts;
    $minutes = max(0, (int)floor($age / 60));
    if ($age <= 10 * 60) {
        return ['online', '在线', $minutes <= 0 ? '刚刚' : $minutes . '分钟前'];
    }
    return ['offline', '异常', $minutes . '分钟前'];
}
?><!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="60">
<title>金貔貅盈亏大屏</title>
<link rel="icon" type="image/png" href="../assets/img/logo.png?v=2">
<link rel="stylesheet" href="../assets/css/app.css?v=20260524-6">
<script src="https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js"></script></head>
<body class="dashboard-page">
<header class="topbar dashboard-topbar">
  <div class="brand brand-with-logo">
    <img src="../assets/img/logo.png" alt="金貔貅">
    <span><b>金貔貅盈亏大屏</b><small>GOLD PIXIU · MONITOR</small></span>
  </div>
  <nav class="nav">
    <a href="accounts.php">账号管理</a><a class="active" href="dashboard.php">盈亏大屏</a><a href="orders.php">续费记录</a><a href="logout.php">退出</a>
  </nav>
</header>
<main class="wrap">
  <section class="panel dashboard-hero">
    <form class="toolbar" method="get">
      <div><label>用户</label><select name="customer" id="customerSelect"><option value="">全部</option><?php foreach($customers as $c): ?><option <?= $customer===$c['customer_name']?'selected':'' ?>><?= h($c['customer_name']) ?></option><?php endforeach; ?></select></div>
      <div><label>账号</label><select name="account"><option value="">全部</option><?php foreach($accounts as $a): ?><option <?= $account===$a['account_login']?'selected':'' ?>><?= h($a['account_login']) ?></option><?php endforeach; ?></select></div>
      <div><label>开始</label><input type="date" name="date_from" value="<?= h($dateFrom) ?>"></div>
      <div><label>结束</label><input type="date" name="date_to" value="<?= h($dateTo) ?>"></div>
      <button class="btn primary">筛选</button>
    </form>
    <div class="grid cols-4">
      <div class="kpi metric-card k-accounts"><div class="muted">账号数</div><div class="num"><?= (int)$kpi['account_count'] ?></div><div class="metric-note">当前筛选范围</div></div>
      <div class="kpi metric-card k-realized <?= pnl_class($kpi['realized_sum']) ?>"><div class="muted">已实现盈亏</div><div class="num"><?= number_format((float)$kpi['realized_sum'],2) ?></div><div class="metric-note">按每日最新快照累计</div></div>
      <div class="kpi metric-card k-floating <?= pnl_class($kpi['floating_sum']) ?>"><div class="muted">浮动盈亏合计</div><div class="num"><?= number_format((float)$kpi['floating_sum'],2) ?></div><div class="metric-note">按账号最新快照合计</div></div>
      <div class="kpi metric-card k-balance balance"><div class="muted">真实余额合计</div><div class="num"><?= number_format((float)$kpi['balance_sum'],2) ?></div><div class="metric-note">不含浮动净值</div></div>
    </div>
  </section>
  <section class="panel chart-panel main-chart-panel">
    <h2><?= h($groupTitle) ?></h2>
    <div class="chart chart-large" id="groupChart"></div>
  </section>
  <section class="grid dashboard-chart-grid">
    <div class="chart chart-panel" id="dailyChart"></div>
    <div class="chart chart-panel" id="floatingChart"></div>
  </section>
  <section class="panel chart-panel main-chart-panel">
    <div class="chart chart-large" id="combinedChart"></div>
  </section>
  <section class="panel table-panel">
    <h2>账户最新快照 <span class="refresh-badge" id="refreshBadge">• 自动刷新中 <span id="refreshCountdown">60</span>s</span></h2>
    <table class="data-table"><thead><tr><th>用户</th><th>账号</th><th>余额</th><th>净值</th><th>今日已实现</th><th>浮盈亏</th><th>持仓</th><th>EA状态</th></tr></thead><tbody>
    <?php foreach($latest as $r): $today = $todayRealizedMap[$r['account_login']] ?? null; $eaStatus = ea_status_info($r['last_time'] ?? null); ?><tr>
      <td><?= h($r['customer_name']) ?></td><td><?= h($r['account_login']) ?></td>
      <td><?= number_format((float)$r['balance'],2) ?></td><td><?= number_format((float)$r['equity'],2) ?></td>
      <td class="<?= $today === null ? 'flat' : pnl_class($today) ?>"><?= $today === null ? '-' : number_format((float)$today,2) ?></td>
      <td class="<?= pnl_class($r['floating_profit']) ?>"><?= number_format((float)$r['floating_profit'],2) ?></td><td><?= (int)$r['open_positions'] ?></td><td><span class="ea-status <?= h($eaStatus[0]) ?>"><b><?= h($eaStatus[1]) ?></b><small><?= h($eaStatus[2]) ?></small></span></td>
    </tr><?php endforeach; ?>
    </tbody></table>
  </section>
</main>
<script>
const daily = <?= json_encode($daily, JSON_UNESCAPED_UNICODE) ?>;
const dailyTrend = <?= json_encode($dailyTrend, JSON_UNESCAPED_UNICODE) ?>;
const groupLabels = <?= json_encode($groupLabels, JSON_UNESCAPED_UNICODE) ?>;
const groupRealized = <?= json_encode($groupRealized, JSON_UNESCAPED_UNICODE) ?>;
const groupFloating = <?= json_encode($groupFloating, JSON_UNESCAPED_UNICODE) ?>;
const groupTitle = <?= json_encode($groupTitle, JSON_UNESCAPED_UNICODE) ?>;
const axisColor = '#8b95b0';
const splitColor = 'rgba(216,172,79,.10)';
const titleStyle = {color:'#fff1a8',fontWeight:700,fontSize:14};
document.getElementById('customerSelect')?.addEventListener('change', e => {
  const form = e.target.form;
  if (form?.account) form.account.value = '';
  form?.submit();
});

// 大屏自动刷新倒计时（与 meta refresh 同步显示）
(function(){
  const el = document.getElementById('refreshCountdown');
  if (!el) return;
  let n = 60;
  setInterval(() => { n--; if (n < 0) n = 0; el.textContent = n; }, 1000);
})();
echarts.init(document.getElementById('groupChart')).setOption({
  backgroundColor:'transparent',
  tooltip:{trigger:'axis',backgroundColor:'rgba(12,16,28,.94)',borderColor:'#d8ac4f',textStyle:{color:'#eef3ff'}},
  legend:{top:6,textStyle:{color:axisColor},data:['已实现盈亏','浮动盈亏']},
  grid:{top:46,left:64,right:36,bottom:58},
  xAxis:{type:'category',data:groupLabels,axisLine:{lineStyle:{color:'rgba(216,172,79,.45)'}},axisTick:{show:false},axisLabel:{color:axisColor,interval:0,rotate:groupLabels.length>8?28:0}},
  yAxis:{type:'value',axisLabel:{color:axisColor},splitLine:{lineStyle:{color:splitColor}}},
  series:[
    {name:'已实现盈亏',type:'bar',data:groupRealized,barMaxWidth:34,itemStyle:{color:'#39d98a',borderRadius:[5,5,0,0]}},
    {name:'浮动盈亏',type:'bar',data:groupFloating,barMaxWidth:34,itemStyle:{color:'#42b8ff',borderRadius:[5,5,0,0]}}
  ]
});
const days = daily.map(x=>x.d);
const trendDays = dailyTrend.map(x=>x.d);
const trendRealized = dailyTrend.map(x=>Number(x.realized||0));
const trendFloating = dailyTrend.map(x=>Number(x.floating||0));
echarts.init(document.getElementById('dailyChart')).setOption({
  backgroundColor:'transparent',
  title:{text:'每日已实现盈亏（近 30 天）',textStyle:titleStyle,left:14,top:10},
  tooltip:{trigger:'axis',backgroundColor:'rgba(12,16,28,.94)',borderColor:'#d8ac4f',textStyle:{color:'#eef3ff'}},
  grid:{top:54,left:60,right:26,bottom:48},
  xAxis:{type:'category',data:trendDays,axisLine:{lineStyle:{color:'rgba(216,172,79,.45)'}},axisTick:{show:false},axisLabel:{color:axisColor}},
  yAxis:{type:'value',axisLabel:{color:axisColor},splitLine:{lineStyle:{color:splitColor}}},
  series:[{type:'bar',data:trendRealized,barMaxWidth:42,itemStyle:{color:'#39d98a',borderRadius:[5,5,0,0]}}]
});
echarts.init(document.getElementById('floatingChart')).setOption({
  backgroundColor:'transparent',
  title:{text:'每日浮动盈亏（近 30 天）',textStyle:titleStyle,left:14,top:10},
  tooltip:{trigger:'axis',backgroundColor:'rgba(12,16,28,.94)',borderColor:'#d8ac4f',textStyle:{color:'#eef3ff'}},
  grid:{top:54,left:60,right:26,bottom:48},
  xAxis:{type:'category',data:trendDays,axisLine:{lineStyle:{color:'rgba(216,172,79,.45)'}},axisTick:{show:false},axisLabel:{color:axisColor}},
  yAxis:{type:'value',axisLabel:{color:axisColor},splitLine:{lineStyle:{color:splitColor}}},
  series:[{type:'line',smooth:true,symbolSize:8,data:trendFloating,lineStyle:{color:'#42b8ff',width:3},itemStyle:{color:'#fff1a8',borderColor:'#42b8ff',borderWidth:2},areaStyle:{color:'rgba(66,184,255,.16)'}}]
});

// 每日盈亏曲线图（近 30 天已实现+浮动叠加对比）
if (document.getElementById('combinedChart')) {
  echarts.init(document.getElementById('combinedChart')).setOption({
    backgroundColor:'transparent',
    title:{text:'每日盈亏曲线（近 30 天 · 已实现 vs 浮动）',textStyle:titleStyle,left:14,top:10},
    tooltip:{trigger:'axis',backgroundColor:'rgba(12,16,28,.94)',borderColor:'#d8ac4f',textStyle:{color:'#eef3ff'}},
    legend:{top:8,right:20,textStyle:{color:axisColor},data:['已实现盈亏','浮动盈亏']},
    grid:{top:54,left:60,right:26,bottom:48},
    xAxis:{type:'category',data:trendDays,axisLine:{lineStyle:{color:'rgba(216,172,79,.45)'}},axisTick:{show:false},axisLabel:{color:axisColor}},
    yAxis:{type:'value',axisLabel:{color:axisColor},splitLine:{lineStyle:{color:splitColor}}},
    series:[
      {name:'已实现盈亏',type:'line',smooth:true,symbolSize:7,data:trendRealized,lineStyle:{color:'#39d98a',width:3},itemStyle:{color:'#39d98a'},areaStyle:{color:'rgba(57,217,138,.18)'}},
      {name:'浮动盈亏',type:'line',smooth:true,symbolSize:7,data:trendFloating,lineStyle:{color:'#42b8ff',width:3},itemStyle:{color:'#42b8ff'},areaStyle:{color:'rgba(66,184,255,.14)'}}
    ]
  });
}
</script>
</body></html>
