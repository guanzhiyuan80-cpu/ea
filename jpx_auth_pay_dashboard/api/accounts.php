<?php
require_once __DIR__ . '/../includes/business.php';

$q = trim($_GET['q'] ?? '');
$where = 'WHERE 1=1';
$params = [];
if ($q !== '') {
    $where .= ' AND (account_login LIKE ? OR customer_name LIKE ?)';
    $like = '%' . $q . '%';
    $params = [$like, $like];
}

$stmt = db()->prepare("SELECT id, account_login, customer_name, product, expires_at, last_paid_at, created_at,
                              license_code IS NOT NULL AS has_license
                       FROM accounts $where ORDER BY id DESC LIMIT 300");
$stmt->execute($params);
$items = $stmt->fetchAll();
foreach ($items as &$item) {
    $item['status'] = account_status($item['expires_at'], (bool)$item['has_license']);
}
json_response(['ok' => true, 'items' => $items, 'amount_yuan' => RENEW_AMOUNT_YUAN]);
