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
                  SELECT account_login, MAX(id) AS last_id
                  FROM trade_reports $where
                  GROUP BY account_login
              ) x ON x.last_id = tr.id";

$stmt = db()->prepare("SELECT COUNT(*) AS account_count,
                              IFNULL(SUM(realized_profit),0) AS realized_sum,
                              IFNULL(SUM(balance),0) AS balance_sum,
                              IFNULL(SUM(equity),0) AS equity_sum,
                              IFNULL(SUM(floating_profit),0) AS floating_sum
                       FROM ($latestSql) latest_rows");
$stmt->execute($params);
$kpi = $stmt->fetch();

$dailyDeltaSql = "SELECT l.customer_name, l.account_login, b.d,
                         l.realized_profit AS realized,
                         l.floating_profit AS floating_current,
                         (l.balance - f.balance) AS balance_delta,
                         (l.equity - f.equity) AS equity_delta,
                         (l.floating_profit - f.floating_profit) AS floating_delta
                  FROM (
                      SELECT account_login, DATE(report_time) AS d, MIN(id) AS first_id, MAX(id) AS last_id
                      FROM trade_reports $where
                      GROUP BY account_login, DATE(report_time)
                  ) b
                  JOIN trade_reports f ON f.id = b.first_id
                  JOIN trade_reports l ON l.id = b.last_id";

$stmt = db()->prepare("SELECT d,
                              IFNULL(SUM(realized),0) AS realized,
                              IFNULL(SUM(floating_current),0) AS floating,
                              IFNULL(SUM(balance_delta),0) AS balance_delta,
                              IFNULL(SUM(equity_delta),0) AS equity_delta,
                              IFNULL(SUM(floating_delta),0) AS floating_delta
                       FROM ($dailyDeltaSql) daily_rows GROUP BY d ORDER BY d");
$stmt->execute($params);
$daily = $stmt->fetchAll();
$kpi['realized_sum'] = 0.0;
$kpi['balance_delta_sum'] = 0.0;
$kpi['equity_delta_sum'] = 0.0;
$kpi['floating_delta_sum'] = 0.0;
foreach ($daily as $row) {
    $kpi['realized_sum'] += (float)$row['realized'];
    $kpi['balance_delta_sum'] += (float)$row['balance_delta'];
    $kpi['equity_delta_sum'] += (float)$row['equity_delta'];
    $kpi['floating_delta_sum'] += (float)$row['floating_delta'];
}

$stmt = db()->prepare("$latestSql ORDER BY customer_name, account_login");
$stmt->execute($params);
$latest = $stmt->fetchAll();

// 今日已实现盈亏：按账号取今日（北京时间）最后一条快照的 realized_profit
$stmt = db()->prepare("SELECT tr.account_login, tr.realized_profit AS today_realized
                       FROM trade_reports tr
                       INNER JOIN (
                           SELECT account_login, MAX(id) AS last_id
                           FROM trade_reports
                           WHERE DATE(report_time) = CURDATE()
                           GROUP BY account_login
                       ) m ON m.last_id = tr.id");
$stmt->execute();
$todayRealizedMap = [];
foreach ($stmt->fetchAll() as $row) {
    $todayRealizedMap[$row['account_login']] = (float)$row['today_realized'];
}

$stmt = db()->prepare("SELECT l.account_login,
                              l.realized_profit AS today_realized,
                              (l.balance - f.balance) AS balance_delta,
                              (l.equity - f.equity) AS equity_delta,
                              (l.floating_profit - f.floating_profit) AS floating_delta
                       FROM (
                           SELECT account_login, MIN(id) AS first_id, MAX(id) AS last_id
                           FROM trade_reports
                           WHERE DATE(report_time) = CURDATE()
                           GROUP BY account_login
                       ) b
                       JOIN trade_reports f ON f.id = b.first_id
                       JOIN trade_reports l ON l.id = b.last_id");
$stmt->execute();
$todayDeltaMap = [];
foreach ($stmt->fetchAll() as $row) {
    $todayDeltaMap[$row['account_login']] = [
        'realized' => (float)$row['today_realized'],
        'balance_delta' => (float)$row['balance_delta'],
        'equity_delta' => (float)$row['equity_delta'],
        'floating_delta' => (float)$row['floating_delta'],
    ];
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
        SELECT account_login, MAX(id) AS last_id
        FROM trade_reports $totalProfitWhere
        GROUP BY account_login
    ) m ON m.last_id = tr.id");
$stmt->execute($totalProfitParams);
$latestEquityAllTime = (float)$stmt->fetch()['latest_equity'];
unset($stmt);
// 纯盈利 = 当前净值 − 净入金（美分值）
$totalRealizedSum = $latestEquityAllTime - $netDeposit;

$trendWhere = 'WHERE report_time >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)';
$trendParams = [];
if ($customer !== '') { $trendWhere .= ' AND customer_name = ?'; $trendParams[] = $customer; }
if ($account !== '') { $trendWhere .= ' AND account_login = ?'; $trendParams[] = $account; }

$trendDeltaSql = "SELECT l.account_login, l.customer_name, b.d,
                         l.realized_profit AS realized,
                         l.floating_profit AS floating_current,
                         (l.equity - f.equity) AS equity_delta,
                         (l.floating_profit - f.floating_profit) AS floating_delta
                  FROM (
                      SELECT account_login, DATE(report_time) AS d, MIN(id) AS first_id, MAX(id) AS last_id
                      FROM trade_reports $trendWhere
                      GROUP BY account_login, DATE(report_time)
                  ) b
                  JOIN trade_reports f ON f.id = b.first_id
                  JOIN trade_reports l ON l.id = b.last_id";
$stmt = db()->prepare("SELECT d,
                              IFNULL(SUM(realized),0) AS realized,
                              IFNULL(SUM(floating_current),0) AS floating,
                              IFNULL(SUM(equity_delta),0) AS equity_delta,
                              IFNULL(SUM(floating_delta),0) AS floating_delta
                       FROM ($trendDeltaSql) tr_rows GROUP BY d ORDER BY d");
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
        'equity_delta' => isset($dailyTrendMap[$d]) ? (float)$dailyTrendMap[$d]['equity_delta'] : 0.0,
        'floating_delta' => isset($dailyTrendMap[$d]) ? (float)$dailyTrendMap[$d]['floating_delta'] : 0.0,
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
        $delta = $todayDeltaMap[$r['account_login']] ?? ['equity_delta' => 0.0, 'floating_delta' => 0.0];
        $rankList[] = [
            'customer' => (string)$r['customer_name'],
            'account'  => (string)$r['account_login'],
            'today'    => (float)$today,
            'equity_delta' => (float)$delta['equity_delta'],
            'floating_delta' => (float)$delta['floating_delta'],
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
$rankProfit = array_values(array_filter($rankList, function ($r) { return $r['equity_delta'] > 0; }));
usort($rankProfit, function ($a, $b) { return $b['equity_delta'] <=> $a['equity_delta']; });
$rankTop = array_slice($rankProfit, 0, 10);

$groupTitle = '';
$groupLabels = [];
$groupRealized = [];
$groupFloating = [];
$groupEquityDelta = [];
$groupFloatingDelta = [];
if ($account !== '') {
    $groupTitle = '账号盈亏走势：' . $account;
    foreach ($daily as $row) {
        $groupLabels[] = $row['d'];
        $groupRealized[] = round((float)$row['realized'], 2);
        $groupFloating[] = round((float)$row['floating'], 2);
        $groupEquityDelta[] = round((float)$row['equity_delta'], 2);
        $groupFloatingDelta[] = round((float)$row['floating_delta'], 2);
    }
} else {
    $groupKey = $customer !== '' ? 'account_login' : 'customer_name';
    $groupTitle = $customer !== '' ? '账号盈亏对比' : '用户盈亏对比';
    $stmt = db()->prepare("SELECT $groupKey AS label,
                                  IFNULL(SUM(realized),0) AS realized,
                                  IFNULL(SUM(equity_delta),0) AS equity_delta,
                                  IFNULL(SUM(floating_delta),0) AS floating_delta
                           FROM ($dailyDeltaSql) daily_rows GROUP BY $groupKey ORDER BY $groupKey");
    $stmt->execute($params);
    $realizedByLabel = [];
    $equityDeltaByLabel = [];
    $floatingDeltaByLabel = [];
    foreach ($stmt->fetchAll() as $row) {
        $label = (string)$row['label'];
        $realizedByLabel[$label] = (float)$row['realized'];
        $equityDeltaByLabel[$label] = (float)$row['equity_delta'];
        $floatingDeltaByLabel[$label] = (float)$row['floating_delta'];
    }
    $stmt = db()->prepare("SELECT $groupKey AS label, IFNULL(SUM(floating_profit),0) AS floating
                           FROM ($latestSql) latest_rows GROUP BY $groupKey ORDER BY $groupKey");
    $stmt->execute($params);
    foreach ($stmt->fetchAll() as $row) {
        $label = (string)$row['label'];
        $groupLabels[] = $label;
        $groupRealized[] = round($realizedByLabel[$label] ?? 0.0, 2);
        $groupFloating[] = round((float)$row['floating'], 2);
        $groupEquityDelta[] = round($equityDeltaByLabel[$label] ?? 0.0, 2);
        $groupFloatingDelta[] = round($floatingDeltaByLabel[$label] ?? 0.0, 2);
        unset($realizedByLabel[$label]);
        unset($equityDeltaByLabel[$label], $floatingDeltaByLabel[$label]);
    }
    foreach ($realizedByLabel as $label => $value) {
        $groupLabels[] = $label;
        $groupRealized[] = round((float)$value, 2);
        $groupFloating[] = 0.0;
        $groupEquityDelta[] = round($equityDeltaByLabel[$label] ?? 0.0, 2);
        $groupFloatingDelta[] = round($floatingDeltaByLabel[$label] ?? 0.0, 2);
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
<link rel="stylesheet" href="../assets/css/app.css?v=20260623-1">
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
      <div class="kpi metric-card k-equity-delta <?= pnl_class($kpi['equity_delta_sum']) ?>"><div class="muted">净值变化</div><div class="num"><?= fmtUSD($kpi['equity_delta_sum']) ?></div><div class="metric-note">筛选期首末净值差</div></div>
      <div class="kpi metric-card k-float-delta <?= pnl_class($kpi['floating_delta_sum']) ?>"><div class="muted">浮动变化</div><div class="num"><?= fmtUSD($kpi['floating_delta_sum']) ?></div><div class="metric-note">浮亏扩大为负</div></div>
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
          <table class="data-table account-snapshot-table"><thead><tr><th>用户</th><th>账号</th><th>余额</th><th>净值</th><th>实际盈利</th><th>今日已实现</th><th>今日净值变化</th><th>浮动变化</th><th>浮盈亏</th><th>持仓</th><th>EA状态</th></tr></thead><tbody>
          <?php foreach($latest as $r): $today = $todayRealizedMap[$r['account_login']] ?? null; $todayDelta = $todayDeltaMap[$r['account_login']] ?? null; $eaStatus = ea_status_info($r['last_time'] ?? null); $cap = $capitalByAccount[(string)$r['account_login']] ?? ['deposit_sum' => 0.0, 'withdraw_sum' => 0.0]; $netIn = $cap['deposit_sum'] - $cap['withdraw_sum']; $actual = (float)$r['equity'] - $netIn; ?><tr>
            <td><?= h($r['customer_name']) ?></td><td><?= h($r['account_login']) ?></td>
            <td><?= fmtUSD($r['balance']) ?></td><td><?= fmtUSD($r['equity']) ?></td>
            <td class="<?= pnl_class($actual) ?>"><?= fmtUSD($actual) ?></td>
            <td class="<?= $today === null ? 'flat' : pnl_class($today) ?>"><?= $today === null ? '-' : fmtUSD($today) ?></td>
            <td class="<?= $todayDelta === null ? 'flat' : pnl_class($todayDelta['equity_delta']) ?>"><?= $todayDelta === null ? '-' : fmtUSD($todayDelta['equity_delta']) ?></td>
            <td class="<?= $todayDelta === null ? 'flat' : pnl_class($todayDelta['floating_delta']) ?>"><?= $todayDelta === null ? '-' : fmtUSD($todayDelta['floating_delta']) ?></td>
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
        <h3 class="chart-h3">今日净值增长 · TOP 10</h3>
        <ul class="rank-list rank-list-full">
          <?php if (!$rankTop): ?><li class="rank-empty">暂无净值增长账号</li>
          <?php else: foreach ($rankTop as $i => $r): ?>
            <li>
              <span class="rank-no rank-no-<?= $i < 3 ? ($i+1) : 'n' ?>"><?= $i+1 ?></span>
              <span class="rank-cust"><?= h($r['customer']) ?></span>
              <span class="rank-acc"><?= h($r['account']) ?></span>
              <span class="rank-val <?= pnl_class($r['equity_delta']) ?>"><?= fmtUSD($r['equity_delta']) ?></span>
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
const groupEquityDelta = <?= json_encode($groupEquityDelta, JSON_UNESCAPED_UNICODE) ?>;
const groupFloatingDelta = <?= json_encode($groupFloatingDelta, JSON_UNESCAPED_UNICODE) ?>;
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
  tooltip:{trigger:'axis',backgroundColor:'rgba(12,16,28,.94)',borderColor:'#d8ac4f',textStyle:{color:'#eef3ff'}},
  legend:{top:0,right:10,textStyle:{color:axisColor,fontSize:12},itemWidth:14,itemHeight:8},
  grid:{top:38,left:60,right:18,bottom:38,containLabel:false},
  xAxis:{type:'category',data:groupLabels,axisLine:{lineStyle:{color:'rgba(216,172,79,.45)'}},axisTick:{show:false},axisLabel:{color:axisColor,interval:0,rotate:groupLabels.length>6?28:0,fontSize:12}},
  yAxis:{type:'value',axisLabel:{color:axisColor,fontSize:11,formatter:v=>Number(v).toLocaleString()},splitLine:{lineStyle:{color:splitColor}}},
  series:[
    {name:'已实现',type:'bar',data:groupRealized,barMaxWidth:24,itemStyle:{color:new echarts.graphic.LinearGradient(0,0,0,1,[{offset:0,color:'#5cf1a8'},{offset:1,color:'#1a8a55'}]),borderRadius:[5,5,0,0]}},
    {name:'净值变化',type:'bar',data:groupEquityDelta,barMaxWidth:24,itemStyle:{color:new echarts.graphic.LinearGradient(0,0,0,1,[{offset:0,color:'#fff1a8'},{offset:1,color:'#b78324'}]),borderRadius:[5,5,0,0]}},
    {name:'浮动变化',type:'bar',data:groupFloatingDelta,barMaxWidth:24,itemStyle:{color:new echarts.graphic.LinearGradient(0,0,0,1,[{offset:0,color:'#9bdcff'},{offset:1,color:'#276f9b'}]),borderRadius:[5,5,0,0]}}
  ]
});

const trendDays = dailyTrend.map(x=>String(x.d).slice(5));
const trendRealized = dailyTrend.map(x=>Number(x.realized||0));
const trendEquityDelta = dailyTrend.map(x=>Number(x.equity_delta||0));
const trendFloatingDelta = dailyTrend.map(x=>Number(x.floating_delta||0));
regChart('combinedChart', {
  backgroundColor:'transparent',
  tooltip:{trigger:'axis',backgroundColor:'rgba(12,16,28,.94)',borderColor:'#d8ac4f',textStyle:{color:'#eef3ff'}},
  legend:{top:0,right:10,textStyle:{color:axisColor,fontSize:12},itemWidth:14,itemHeight:8},
  grid:{top:38,left:60,right:18,bottom:32},
  xAxis:{type:'category',data:trendDays,axisLine:{lineStyle:{color:'rgba(216,172,79,.45)'}},axisTick:{show:false},axisLabel:{color:axisColor,fontSize:11,interval:Math.ceil(trendDays.length/10)}},
  yAxis:{type:'value',axisLabel:{color:axisColor,fontSize:11,formatter:v=>Number(v).toLocaleString()},splitLine:{lineStyle:{color:splitColor}}},
  series:[
    {name:'已实现',type:'line',smooth:true,symbol:'circle',symbolSize:5,data:trendRealized,lineStyle:{color:'#39d98a',width:2.5},itemStyle:{color:'#39d98a',borderColor:'#0e1422',borderWidth:1.5}},
    {name:'净值变化',type:'line',smooth:true,symbol:'circle',symbolSize:5,data:trendEquityDelta,lineStyle:{color:'#fff1a8',width:2.7},itemStyle:{color:'#fff1a8',borderColor:'#0e1422',borderWidth:1.5},areaStyle:{color:new echarts.graphic.LinearGradient(0,0,0,1,[{offset:0,color:'rgba(255,241,168,.24)'},{offset:1,color:'rgba(255,241,168,.02)'}])}},
    {name:'浮动变化',type:'line',smooth:true,symbol:'circle',symbolSize:5,data:trendFloatingDelta,lineStyle:{color:'#42b8ff',width:2.2},itemStyle:{color:'#42b8ff',borderColor:'#0e1422',borderWidth:1.5}}
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
