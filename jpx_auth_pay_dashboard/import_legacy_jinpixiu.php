<?php
require_once __DIR__ . '/includes/business.php';

// Import old build/licenses rows into the new billing system.
$legacyDbName = $_GET['db'] ?? ($argv[1] ?? 'jinpixiu');

$pdo = db();
$legacy = new PDO(
    sprintf('mysql:host=%s;port=%d;dbname=%s;charset=utf8mb4', DB_HOST, DB_PORT, $legacyDbName),
    DB_USER,
    DB_PASS,
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
);

$rows = $legacy->query("SELECT l.*
    FROM licenses l
    INNER JOIN (
        SELECT account, product, MAX(expiry_date) AS max_expiry
        FROM licenses GROUP BY account, product
    ) x ON x.account = l.account AND x.product = l.product AND x.max_expiry = l.expiry_date
    ORDER BY l.id")->fetchAll();

$imported = 0;
$skipped = 0;
foreach ($rows as $r) {
    $account = (string)$r['account'];
    $customer = trim((string)($r['remark'] ?? ''));
    if ($customer === '') $customer = '旧授权用户';
    $note = '从旧 jinpixiu licenses 导入；原备注：' . $customer;
    $expiresAt = $r['expiry_date'] . ' 23:59:59';

    try {
        $pdo->beginTransaction();
        $stmt = $pdo->prepare("INSERT INTO accounts
            (account_login, customer_name, product, license_code, expires_at, last_paid_at, admin_note, created_by, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'legacy_import', ?, NOW())");
        $stmt->execute([
            $account,
            $customer,
            $r['product'] ?: DEFAULT_PRODUCT,
            $r['license_code'],
            $expiresAt,
            $r['created_at'],
            $note,
            $r['created_at'],
        ]);
        $accountId = (int)$pdo->lastInsertId();

        $stmt = $pdo->prepare("INSERT INTO license_history
            (account_id, order_id, license_code, starts_at, expires_at, amount_yuan, created_at)
            VALUES (?, NULL, ?, ?, ?, 0, ?)");
        $stmt->execute([$accountId, $r['license_code'], $r['created_at'], $expiresAt, $r['created_at']]);
        $licenseId = (int)$pdo->lastInsertId();
        $pdo->prepare("UPDATE accounts SET latest_license_id = ? WHERE id = ?")->execute([$licenseId, $accountId]);
        $pdo->commit();
        $imported++;
    } catch (PDOException $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        if (strpos($e->getMessage(), '1062') !== false) $skipped++;
        else throw $e;
    }
}

if (PHP_SAPI === 'cli') {
    echo "imported=$imported skipped=$skipped legacy_db=$legacyDbName\n";
} else {
    header('Content-Type: text/plain; charset=utf-8');
    echo "导入完成：imported=$imported skipped=$skipped legacy_db=$legacyDbName";
}
