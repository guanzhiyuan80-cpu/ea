<?php
require_once __DIR__ . '/../includes/business.php';

$data = read_json_body();
if (!verify_ea_signature($data)) json_response(['ok' => false, 'msg' => 'bad_signature'], 403);

$accountLogin = trim((string)($data['account_login'] ?? ''));
$serverName = trim((string)($data['server'] ?? ''));
if ($accountLogin === '' || $serverName === '') json_response(['ok' => false, 'msg' => '缺少账号或服务器'], 400);

$stmt = db()->prepare("SELECT id, customer_name FROM accounts WHERE account_login = ? AND server_name = ?");
$stmt->execute([$accountLogin, $serverName]);
$account = $stmt->fetch();

$reportTime = trim((string)($data['timestamp'] ?? ''));
if ($reportTime === '') $reportTime = date('Y-m-d H:i:s');

$stmt = db()->prepare("INSERT INTO trade_reports
    (account_id, account_login, server_name, customer_name, report_time, balance, equity, floating_profit, realized_profit, open_positions, total_exposure, raw_json)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
$stmt->execute([
    $account ? (int)$account['id'] : null,
    $accountLogin,
    $serverName,
    $account['customer_name'] ?? null,
    $reportTime,
    (float)($data['balance'] ?? 0),
    (float)($data['equity'] ?? 0),
    (float)($data['floating_profit'] ?? ($data['profit'] ?? 0)),
    (float)($data['realized_profit'] ?? 0),
    (int)($data['open_positions'] ?? 0),
    (float)($data['total_exposure'] ?? 0),
    json_encode($data, JSON_UNESCAPED_UNICODE),
]);

json_response(['ok' => true, 'status' => 'received']);
