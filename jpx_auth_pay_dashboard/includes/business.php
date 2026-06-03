<?php
require_once __DIR__ . '/db.php';

function h(?string $value): string {
    return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8');
}

function generate_license_code(string $account, string $expiryYmd): string {
    $plain = $account . '|' . $expiryYmd;
    $key = LICENSE_XOR_KEY;
    $out = '';
    for ($i = 0, $n = strlen($plain), $k = strlen($key); $i < $n; $i++) {
        $out .= chr(ord($plain[$i]) ^ ord($key[$i % $k]));
    }
    return base64_encode($out);
}

function account_status(?string $expiresAt, bool $hasLicense): string {
    if (!$hasLicense || !$expiresAt) return 'unpaid';
    $today = new DateTime('today');
    $exp = new DateTime(substr($expiresAt, 0, 10));
    $diff = (int)$today->diff($exp)->format('%r%a');
    if ($diff < 0) return 'expired';
    if ($diff <= EXPIRE_WARNING_DAYS) return 'warning';
    return 'active';
}

function add_month_from_expiry(?string $expiresAt): string {
    $today = new DateTime('today');
    $base = $today;
    if ($expiresAt) {
        $current = new DateTime(substr($expiresAt, 0, 10));
        if ($current > $today) $base = $current;
    }
    $base->modify('+' . RENEW_MONTHS . ' month');
    return $base->format('Y-m-d 23:59:59');
}

function complete_paid_order(string $orderNo, string $transactionId = ''): ?array {
    $pdo = db();
    $pdo->beginTransaction();
    try {
        $stmt = $pdo->prepare("SELECT * FROM renew_orders WHERE order_no = ? FOR UPDATE");
        $stmt->execute([$orderNo]);
        $order = $stmt->fetch();
        if (!$order) {
            $pdo->rollBack();
            return null;
        }
        if ($order['status'] === 'paid') {
            $pdo->commit();
            return $order;
        }

        $stmt = $pdo->prepare("SELECT * FROM accounts WHERE id = ? FOR UPDATE");
        $stmt->execute([(int)$order['account_id']]);
        $account = $stmt->fetch();
        if (!$account) {
            throw new RuntimeException('账号不存在');
        }

        $newExpiry = add_month_from_expiry($account['expires_at']);
        $license = generate_license_code($account['account_login'], date('Ymd', strtotime($newExpiry)));

        $stmt = $pdo->prepare("INSERT INTO license_history
            (account_id, order_id, license_code, starts_at, expires_at, amount_yuan, created_at)
            VALUES (?, ?, ?, NOW(), ?, ?, NOW())");
        $stmt->execute([(int)$account['id'], (int)$order['id'], $license, $newExpiry, (float)$order['amount_yuan']]);
        $licenseId = (int)$pdo->lastInsertId();

        $stmt = $pdo->prepare("UPDATE accounts
            SET license_code = ?, expires_at = ?, last_paid_at = NOW(), latest_license_id = ?, updated_at = NOW()
            WHERE id = ?");
        $stmt->execute([$license, $newExpiry, $licenseId, (int)$account['id']]);

        $stmt = $pdo->prepare("UPDATE renew_orders
            SET status = 'paid', paid_at = NOW(), wx_transaction_id = ?, updated_at = NOW()
            WHERE id = ?");
        $stmt->execute([$transactionId, (int)$order['id']]);

        $pdo->commit();
        $order['status'] = 'paid';
        return $order;
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }
}

function verify_ea_signature(array $data): bool {
    if (API_SHARED_SECRET === 'CHANGE_ME_EA_HTTP_SECRET') return true;
    $sig = (string)($data['signature'] ?? '');
    $payload = implode('|', [
        (string)($data['account_login'] ?? ''),
        (string)($data['timestamp'] ?? ''),
    ]);
    return hash_equals(hash_hmac('sha256', $payload, API_SHARED_SECRET), $sig);
}
