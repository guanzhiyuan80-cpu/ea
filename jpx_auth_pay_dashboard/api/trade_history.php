<?php
require_once __DIR__ . '/../includes/business.php';

$data = read_json_body();
if (!verify_ea_signature($data)) json_response(['ok' => false, 'msg' => 'bad_signature'], 403);

$required = ['account_login', 'server', 'deal_ticket', 'symbol', 'deal_type', 'entry_type', 'deal_time'];
foreach ($required as $field) {
    if (!isset($data[$field]) || (string)$data[$field] === '') json_response(['ok' => false, 'msg' => '缺少字段：' . $field], 400);
}

$stmt = db()->prepare("SELECT id FROM accounts WHERE account_login = ? AND server_name = ?");
$stmt->execute([(string)$data['account_login'], (string)$data['server']]);
$accountId = $stmt->fetchColumn() ?: null;

$stmt = db()->prepare("INSERT IGNORE INTO trade_history
    (account_id, account_login, server_name, deal_ticket, symbol, deal_type, entry_type, volume, price, profit, commission, swap, total_pnl, deal_time, magic_number)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
$stmt->execute([
    $accountId,
    (string)$data['account_login'],
    (string)$data['server'],
    (string)$data['deal_ticket'],
    (string)$data['symbol'],
    (string)$data['deal_type'],
    (string)$data['entry_type'],
    (float)($data['volume'] ?? 0),
    (float)($data['price'] ?? 0),
    (float)($data['profit'] ?? 0),
    (float)($data['commission'] ?? 0),
    (float)($data['swap'] ?? 0),
    (float)($data['total_pnl'] ?? 0),
    (string)$data['deal_time'],
    isset($data['magic_number']) ? (int)$data['magic_number'] : null,
]);

json_response(['ok' => true]);
