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
                              IFNULL(SUM(equity),0) AS equity_sum,
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

// 总盈利（纯盈利）= 全账号当前净值 − 净入金（入金出金流水真实值）
// 不受 date_from/date_to 限制，仅受 customer/account 筛选
$totalProfitWhere = 'WHERE 1=1';
$totalProfitParams = [];
if ($customer !== '') { $totalProfitWhere .= ' AND customer_name = ?'; $totalProfitParams[] = $customer; }
if ($account !== '') { $totalProfitWhere .= ' AND account_login = ?'; $totalProfitParams[] = $account; }

$capitalWhere = 'WHERE 1=1';
$capitalParams = [];
if ($customer !== '') { $capitalWhere .= ' AND a.customer_name = ?'; $capitalParams[] = $customer; }
if ($account !== '') { $capitalWhere .= ' AND th.account_login = ?'; $capitalParams[] = $account; }
$stmt = db()->prepare("
    SELECT
      IFNULL(SUM(CASE WHEN th.total_pnl > 0 THEN th.total_pnl ELSE 0 END), 0) AS deposit_sum,
      IFNULL(SUM(CASE WHEN th.total_pnl < 0 THEN -th.total_pnl ELSE 0 END), 0) AS withdraw_sum
    FROM trade_history th
    LEFT JOIN accounts a ON a.account_login = th.account_login
    $capitalWhere
      AND th.deal_type IN ('balance','credit','charge','correction','bonus')
");
$stmt->execute($capitalParams);
$capital = $stmt->fetch() ?: ['deposit_sum' => 0, 'withdraw_sum' => 0];
$depositSum = (float)$capital['deposit_sum'];
$withdrawSum = (float)$capital['withdraw_sum'];
$netDeposit = $depositSum - $withdrawSum;

$stmt = db()->prepare("
    SELECT
      th.account_login,
      IFNULL(SUM(CASE WHEN th.total_pnl > 0 THEN th.total_pnl ELSE 0 END), 0) AS deposit_sum,
      IFNULL(SUM(CASE WHEN th.total_pnl < 0 THEN -th.total_pnl ELSE 0 END), 0) AS withdraw_sum
    FROM trade_history th
    LEFT JOIN accounts a ON a.account_login = th.account_login
    $capitalWhere
      AND th.deal_type IN ('balance','credit','charge','correction','bonus')
    GROUP BY th.account_login
");
$stmt->execute($capitalParams);
$capitalByAccount = [];
foreach ($stmt->fetchAll() as $row) {
    $capitalByAccount[(string)$row['account_login']] = [
        'deposit_sum' => (float)$row['deposit_sum'],
        'withdraw_sum' => (float)$row['withdraw_sum'],
    ];
}

// 全账号当前最新净值总和（不受日期筛选，用于总盈利计算）
$stmt = db()->prepare("SELECT IFNULL(SUM(tr.equity),0) AS latest_equity
    FROM trade_reports tr
    INNER JOIN (
        SELECT account_login, MAX(report_time) AS last_time
        FROM trade_reports $totalProfitWhere
        GROUP BY account_login
    ) m ON m.account_login = tr.account_login AND m.last_time = tr.report_time");
$stmt->execute($totalProfitParams);
$latestEquityAllTime = (float)$stmt->fetch()['latest_equity'];
unset($stmt);
// 纯盈利 = 当前净值 − 净入金（美分值）
$totalRealizedSum = $latestEquityAllTime - $netDeposit;

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

// 侧边栏饰金：余额占比饼 / EA 在线状态饼 / 今日盈亏 TOP/BOTTOM 榜
function ea_status_info(?string $lastTime): array {
    if (!$lastTime) return ['offline', '异常', '无心跳'];
    $ts = strtotime($lastTime);
    if (!$ts) return ['offline', '异常', '时间异常'];
    $age = time() - $ts;
    $minutes = max(0, (int)floor($age / 60));
    if ($age <= 10 * 60) {
        return ['online', '在线', $minutes <= 0 ? '刚刚' : $minutes . '分钟前'];
    }
    return ['offline', '异常', $minutes . '分钟前'];
}
$balanceByCustomer = [];
$equityByCustomer = [];
$onlineCount = 0;
$offlineCount = 0;
$rankList = [];
foreach ($latest as $r) {
    $cust = trim((string)($r['customer_name'] ?? '')) ?: '未命名';
    $balanceByCustomer[$cust] = ($balanceByCustomer[$cust] ?? 0) + (float)$r['balance'];
    $equityByCustomer[$cust]  = ($equityByCustomer[$cust]  ?? 0) + (float)$r['equity'];
    $info = ea_status_info($r['last_time'] ?? null);
    if ($info[0] === 'online') $onlineCount++; else $offlineCount++;
    $today = $todayRealizedMap[$r['account_login']] ?? null;
    if ($today !== null) {
        $rankList[] = [
            'customer' => (string)$r['customer_name'],
            'account'  => (string)$r['account_login'],
            'today'    => (float)$today,
        ];
    }
}
arsort($balanceByCustomer);
$balancePieData = [];
foreach ($balanceByCustomer as $c => $v) {
    if ($v <= 0) continue;
    $balancePieData[] = ['name' => $c, 'value' => round($v, 2)];
}
arsort($equityByCustomer);
$equityPieData = [];
foreach ($equityByCustomer as $c => $v) {
    if ($v <= 0) continue;
    $equityPieData[] = ['name' => $c, 'value' => round($v, 2)];
}
usort($rankList, function ($a, $b) { return $b['today'] <=> $a['today']; });
$rankProfit = array_values(array_filter($rankList, function ($r) { return $r['today'] > 0; }));
$rankTop = array_slice($rankProfit, 0, 10);

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
function fmtUSD($cents): string {
    $dollars = (float)$cents / 100;
    if ($dollars >= 0) return '$' . number_format($dollars, 2);
    return '-$' . number_format(abs($dollars), 2);
}
?><!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="60">
<title>金貔貅盈亏大屏</title>
<link rel="icon" type="image/png" href="../assets/img/logo.png?v=2">
<link rel="stylesheet" href="../assets/css/app.css?v=20260524-27">
<script src="https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js"></script></head>
<body class="dashboard-page dashboard-fullscreen">
<header class="topbar dashboard-topbar dashboard-topbar-flat">
  <div class="brand brand-with-logo">
    <img src="../assets/img/logo.png" alt="金貔貅">
    <span><b>金貔貅盈亏大屏</b><small>GOLD PIXIU · MONITOR</small></span>
  </div>
  <form class="toolbar dashboard-toolbar dashboard-toolbar-inline" method="get">
    <div><label>用户</label><select name="customer" id="customerSelect"><option value="">全部</option><?php foreach($customers as $c): ?><option <?= $customer===$c['customer_name']?'selected':'' ?>><?= h($c['customer_name']) ?></option><?php endforeach; ?></select></div>
    <div><label>账号</label><select name="account"><option value="">全部</option><?php foreach($accounts as $a): ?><option <?= $account===$a['account_login']?'selected':'' ?>><?= h($a['account_login']) ?></option><?php endforeach; ?></select></div>
    <div><label>开始</label><input type="date" name="date_from" value="<?= h($dateFrom) ?>"></div>
    <div><label>结束</label><input type="date" name="date_to" value="<?= h($dateTo) ?>"></div>
    <button class="btn primary">筛选</button>
  </form>
  <span class="refresh-badge" id="refreshBadge">• 自动刷新中 <span id="refreshCountdown">60</span>s</span>
</header>
<main class="dashboard-main-wrap">
  <div class="dashboard-body">
    <aside class="dashboard-side-left">
      <div class="kpi metric-card k-accounts"><div class="muted">账号数</div><div class="num"><?= (int)$kpi['account_count'] ?></div><div class="metric-note">筛选范围 · 在线 <?= (int)$onlineCount ?> / 异常 <?= (int)$offlineCount ?></div></div>
      <div class="kpi metric-card k-realized <?= pnl_class($kpi['realized_sum']) ?>"><div class="muted">已实现盈亏</div><div class="num"><?= fmtUSD($kpi['realized_sum']) ?></div><div class="metric-note">按每日最新快照累计</div></div>
      <div class="kpi metric-card k-floating <?= pnl_class($kpi['floating_sum']) ?>"><div class="muted">浮动盈亏合计</div><div class="num"><?= fmtUSD($kpi['floating_sum']) ?></div><div class="metric-note">账号最新快照合计</div></div>
      <div class="kpi metric-card k-balance balance"><div class="muted">结余合计</div><div class="num"><?= fmtUSD($kpi['balance_sum']) ?></div><div class="metric-note">不含浮动净值</div></div>
      <div class="kpi metric-card k-equity"><div class="muted">净值合计</div><div class="num"><?= fmtUSD($kpi['equity_sum']) ?></div><div class="metric-note">结余 + 浮动盈亏</div></div>
      <div class="kpi metric-card k-profit <?= pnl_class($totalRealizedSum) ?>"><div class="muted">总盈利</div><div class="num"><?= fmtUSD($totalRealizedSum) ?></div><div class="metric-note">净值 − 净入金</div></div>
      <section class="panel side-card side-card-status">
        <h3 class="chart-h3">EA 在线状态</h3>
        <div class="chart chart-fill" id="statusPie"></div>
      </section>
    </aside>

    <section class="dashboard-center">
      <div class="panel chart-card-double">
        <div class="chart-half">
          <h3 class="chart-h3"><?= h($groupTitle) ?></h3>
          <div class="chart chart-fill" id="groupChart"></div>
        </div>
        <div class="chart-half">
          <h3 class="chart-h3">每日盈亏曲线（近 30 天）</h3>
          <div class="chart chart-fill" id="combinedChart"></div>
        </div>
      </div>
      <div class="panel table-panel-fill">
        <h2>账户最新快照 <span class="refresh-badge-inline">在线 <b><?= (int)$onlineCount ?></b> · 异常 <b><?= (int)$offlineCount ?></b></span></h2>
        <div class="table-scroll">
          <table class="data-table"><thead><tr><th>用户</th><th>账号</th><th>余额</th><th>净值</th><th>实际盈利</th><th>今日已实现</th><th>浮盈亏</th><th>持仓</th><th>EA状态</th></tr></thead><tbody>
          <?php foreach($latest as $r): $today = $todayRealizedMap[$r['account_login']] ?? null; $eaStatus = ea_status_info($r['last_time'] ?? null); $cap = $capitalByAccount[(string)$r['account_login']] ?? ['deposit_sum' => 0.0, 'withdraw_sum' => 0.0]; $netIn = $cap['deposit_sum'] - $cap['withdraw_sum']; $actual = (float)$r['equity'] - $netIn; ?><tr>
            <td><?= h($r['customer_name']) ?></td><td><?= h($r['account_login']) ?></td>
            <td><?= fmtUSD($r['balance']) ?></td><td><?= fmtUSD($r['equity']) ?></td>
            <td class="<?= pnl_class($actual) ?>"><?= fmtUSD($actual) ?></td>
            <td class="<?= $today === null ? 'flat' : pnl_class($today) ?>"><?= $today === null ? '-' : fmtUSD($today) ?></td>
            <td class="<?= pnl_class($r['floating_profit']) ?>"><?= fmtUSD($r['floating_profit']) ?></td><td><?= (int)$r['open_positions'] ?></td><td><span class="ea-status <?= h($eaStatus[0]) ?>"><b><?= h($eaStatus[1]) ?></b><small><?= h($eaStatus[2]) ?></small></span></td>
          </tr><?php endforeach; ?>
          </tbody></table>
        </div>
      </div>
    </section>

    <aside class="dashboard-side-right">
      <section class="panel side-card">
        <h3 class="chart-h3">结余分布 · 按用户 <small style="font-size:11px;color:#5d6781;font-weight:400;letter-spacing:0">· USD</small></h3>
        <div class="chart chart-fill" id="balancePie"></div>
      </section>
      <section class="panel side-card">
        <h3 class="chart-h3">净值分布 · 按用户 <small style="font-size:11px;color:#5d6781;font-weight:400;letter-spacing:0">· USD</small></h3>
        <div class="chart chart-fill" id="equityPie"></div>
      </section>
      <section class="panel side-card rank-card">
        <h3 class="chart-h3">今日盈利 · 榜单 TOP 10</h3>
        <ul class="rank-list rank-list-full">
          <?php if (!$rankTop): ?><li class="rank-empty">暂无盈利账号</li>
          <?php else: foreach ($rankTop as $i => $r): ?>
            <li>
              <span class="rank-no rank-no-<?= $i < 3 ? ($i+1) : 'n' ?>"><?= $i+1 ?></span>
              <span class="rank-cust"><?= h($r['customer']) ?></span>
              <span class="rank-acc"><?= h($r['account']) ?></span>
              <span class="rank-val pos"><?= fmtUSD($r['today']) ?></span>
            </li>
          <?php endforeach; endif; ?>
        </ul>
      </section>
    </aside>
  </div>
</main>
<script>
const dailyTrend = <?= json_encode($dailyTrend, JSON_UNESCAPED_UNICODE) ?>;
const groupLabels = <?= json_encode($groupLabels, JSON_UNESCAPED_UNICODE) ?>;
const groupRealized = <?= json_encode($groupRealized, JSON_UNESCAPED_UNICODE) ?>;
const groupFloating = <?= json_encode($groupFloating, JSON_UNESCAPED_UNICODE) ?>;
const balancePie = <?= json_encode($balancePieData, JSON_UNESCAPED_UNICODE) ?>;
const equityPie = <?= json_encode($equityPieData, JSON_UNESCAPED_UNICODE) ?>;
const onlineCount = <?= (int)$onlineCount ?>;
const offlineCount = <?= (int)$offlineCount ?>;
const axisColor = '#8b95b0';
const splitColor = 'rgba(216,172,79,.10)';
function fmtU(v){ return Math.round(v/100).toLocaleString()+'U'; }
document.getElementById('customerSelect')?.addEventListener('change', e => {
  const form = e.target.form;
  if (form?.account) form.account.value = '';
  form?.submit();
});
(function(){
  const el = document.getElementById('refreshCountdown');
  if (!el) return;
  let n = 60;
  setInterval(() => { n--; if (n < 0) n = 0; el.textContent = n; }, 1000);
})();

const charts = [];
function regChart(id, opt){
  const dom = document.getElementById(id);
  if (!dom) return null;
  const ch = echarts.init(dom);
  ch.setOption(opt);
  charts.push(ch);
  return ch;
}

regChart('groupChart', {
  backgroundColor:'transparent',
  tooltip:{trigger:'axis',backgroundColor:'rgba(12,16,28,.94)',borderColor:'#d8ac4f',textStyle:{color:'#eef3ff'},formatter:p=>{const it=p[0];return `${it.axisValueLabel}<br/>已实现 <b style="color:#3ddc97">${Number(it.value||0).toLocaleString()}</b>`}},
  legend:{show:false},
  grid:{top:30,left:60,right:18,bottom:38,containLabel:false},
  xAxis:{type:'category',data:groupLabels,axisLine:{lineStyle:{color:'rgba(216,172,79,.45)'}},axisTick:{show:false},axisLabel:{color:axisColor,interval:0,rotate:groupLabels.length>6?28:0,fontSize:12}},
  yAxis:{type:'value',axisLabel:{color:axisColor,fontSize:11,formatter:v=>Number(v).toLocaleString()},splitLine:{lineStyle:{color:splitColor}}},
  series:[
    {name:'已实现',type:'bar',data:groupRealized,barMaxWidth:38,itemStyle:{color:new echarts.graphic.LinearGradient(0,0,0,1,[{offset:0,color:'#5cf1a8'},{offset:1,color:'#1a8a55'}]),borderRadius:[6,6,0,0],shadowColor:'rgba(57,217,138,.35)',shadowBlur:8},label:{show:true,position:'top',color:'#a8f0c8',fontSize:11,fontWeight:600,formatter:p=>p.value>0?Number(p.value).toLocaleString():''}}
  ]
});

const trendDays = dailyTrend.map(x=>String(x.d).slice(5));
const trendRealized = dailyTrend.map(x=>Number(x.realized||0));
regChart('combinedChart', {
  backgroundColor:'transparent',
  tooltip:{trigger:'axis',backgroundColor:'rgba(12,16,28,.94)',borderColor:'#d8ac4f',textStyle:{color:'#eef3ff'},formatter:p=>{const it=p[0];return `${it.axisValueLabel}<br/>已实现 <b style="color:#3ddc97">${Number(it.value||0).toLocaleString()}</b>`}},
  legend:{show:false},
  grid:{top:24,left:60,right:18,bottom:32},
  xAxis:{type:'category',data:trendDays,axisLine:{lineStyle:{color:'rgba(216,172,79,.45)'}},axisTick:{show:false},axisLabel:{color:axisColor,fontSize:11,interval:Math.ceil(trendDays.length/10)}},
  yAxis:{type:'value',axisLabel:{color:axisColor,fontSize:11,formatter:v=>Number(v).toLocaleString()},splitLine:{lineStyle:{color:splitColor}}},
  series:[
    {name:'已实现',type:'line',smooth:true,symbol:'circle',symbolSize:6,data:trendRealized,lineStyle:{color:'#39d98a',width:2.8},itemStyle:{color:'#39d98a',borderColor:'#0e1422',borderWidth:1.5},areaStyle:{color:new echarts.graphic.LinearGradient(0,0,0,1,[{offset:0,color:'rgba(57,217,138,.42)'},{offset:1,color:'rgba(57,217,138,.02)'}])}}
  ]
});

regChart('balancePie', {
  backgroundColor:'transparent',
  tooltip:{trigger:'item',backgroundColor:'rgba(12,16,28,.94)',borderColor:'#d8ac4f',textStyle:{color:'#eef3ff'},
    formatter:p=>`${p.name}<br/>结余 <b style="color:#f4f8ff;font-size:14px">${Math.round(p.value/100).toLocaleString()}</b> USD<br/>占比 ${p.percent.toFixed(1)}%`},
  legend:{
    type:'scroll',orient:'vertical',right:2,top:'middle',
    formatter:nm=>{const d=balancePie.find(x=>x.name===nm);const n=d?Math.round(d.value/100).toLocaleString():'';return `{nm|${nm}}{vl|${n}}`},
    textStyle:{color:axisColor,fontSize:12,rich:{
      nm:{width:36,color:'#d8e0f0',fontSize:12},
      vl:{width:66,color:'#f4f8ff',fontSize:12,align:'right',fontFamily:'Consolas,monospace',fontWeight:'bold'}
    }},
    itemHeight:10,itemWidth:10,itemGap:8
  },
  color:['#d8ac4f','#42b8ff','#39d98a','#7c5cff','#ff8a5c','#9bdcff','#b29bff','#7af0b5','#ffd700','#ff6d7c'],
  series:[{
    type:'pie',
    radius:['46%','72%'],
    center:['28%','50%'],
    avoidLabelOverlap:true,
    label:{show:false},
    labelLine:{show:false},
    data:balancePie,
    itemStyle:{borderColor:'#0e1422',borderWidth:2}
  }]
});

regChart('equityPie', {
  backgroundColor:'transparent',
  tooltip:{trigger:'item',backgroundColor:'rgba(12,16,28,.94)',borderColor:'#d8ac4f',textStyle:{color:'#eef3ff'},
    formatter:p=>`${p.name}<br/>净值 <b style="color:#f4f8ff;font-size:14px">${Math.round(p.value/100).toLocaleString()}</b> USD<br/>占比 ${p.percent.toFixed(1)}%`},
  legend:{
    type:'scroll',orient:'vertical',right:2,top:'middle',
    formatter:nm=>{const d=equityPie.find(x=>x.name===nm);const n=d?Math.round(d.value/100).toLocaleString():'';return `{nm|${nm}}{vl|${n}}`},
    textStyle:{color:axisColor,fontSize:12,rich:{
      nm:{width:36,color:'#d8e0f0',fontSize:12},
      vl:{width:66,color:'#f4f8ff',fontSize:12,align:'right',fontFamily:'Consolas,monospace',fontWeight:'bold'}
    }},
    itemHeight:10,itemWidth:10,itemGap:8
  },
  color:['#d8ac4f','#42b8ff','#39d98a','#7c5cff','#ff8a5c','#9bdcff','#b29bff','#7af0b5','#ffd700','#ff6d7c'],
  series:[{
    type:'pie',
    radius:['46%','72%'],
    center:['28%','50%'],
    avoidLabelOverlap:true,
    label:{show:false},
    labelLine:{show:false},
    data:equityPie,
    itemStyle:{borderColor:'#0e1422',borderWidth:2}
  }]
});

regChart('statusPie', {
  backgroundColor:'transparent',
  tooltip:{trigger:'item',backgroundColor:'rgba(12,16,28,.94)',borderColor:'#d8ac4f',textStyle:{color:'#eef3ff'}},
  legend:{bottom:4,left:'center',textStyle:{color:axisColor,fontSize:13},itemHeight:10,itemWidth:16,itemGap:14},
  series:[{
    type:'pie',
    radius:['58%','78%'],
    center:['50%','46%'],
    avoidLabelOverlap:true,
    label:{show:true,position:'center',formatter:[`{val|${onlineCount+offlineCount}}`,'{lab|账号总数}'].join('\n'),rich:{val:{color:'#fff1a8',fontSize:30,fontWeight:700,lineHeight:34},lab:{color:'#a3acc4',fontSize:13,lineHeight:18}}},
    labelLine:{show:false},
    data:[
      {name:'在线',value:onlineCount,itemStyle:{color:'#39d98a'}},
      {name:'异常',value:offlineCount,itemStyle:{color:'#ff6d7c'}}
    ],
    itemStyle:{borderColor:'#0e1422',borderWidth:2}
  }]
});

function resizeAll(){ charts.forEach(c => c && c.resize()); }
window.addEventListener('resize', resizeAll);
window.addEventListener('load', () => setTimeout(resizeAll, 60));
</script>
</body></html>
