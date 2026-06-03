<?php
require_once __DIR__ . '/../includes/business.php';

$data = $_SERVER['REQUEST_METHOD'] === 'POST' ? read_json_body() : $_GET;
if (!verify_ea_signature($data)) json_response(['authorized' => false, 'status' => 'bad_signature'], 403);

$accountLogin = trim((string)($data['account_login'] ?? ''));
$serverName = trim((string)($data['server'] ?? ''));
if ($accountLogin === '' || $serverName === '') json_response(['authorized' => false, 'status' => 'missing_fields'], 400);

$stmt = db()->prepare("SELECT * FROM accounts WHERE account_login = ? AND server_name = ? LIMIT 1");
$stmt->execute([$accountLogin, $serverName]);
$account = $stmt->fetch();
$authorized = false;
$status = 'not_found';
$warning = false;
$daysLeft = null;

if ($account) {
    $status = account_status($account['expires_at'], !empty($account['license_code']));
    if (in_array($status, ['active', 'warning'], true)) {
        $authorized = true;
        $today = new DateTime('today');
        $exp = new DateTime(substr($account['expires_at'], 0, 10));
        $daysLeft = (int)$today->diff($exp)->format('%r%a');
        $warning = $daysLeft <= EXPIRE_WARNING_DAYS;
        db()->prepare("UPDATE accounts SET last_heartbeat_at = NOW() WHERE id = ?")->execute([(int)$account['id']]);
    }
    db()->prepare("INSERT INTO heartbeat_logs(account_id, account_login, server_name, authorized, ip_address)
                   VALUES(?, ?, ?, ?, ?)")
        ->execute([(int)$account['id'], $accountLogin, $serverName, $authorized ? 1 : 0, $_SERVER['REMOTE_ADDR'] ?? null]);
}

json_response([
    'authorized' => $authorized,
    'status' => $status,
    'expires_at' => $account['expires_at'] ?? null,
    'days_left' => $daysLeft,
    'renew_warning' => $warning,
    'warning_days' => EXPIRE_WARNING_DAYS,
]);
