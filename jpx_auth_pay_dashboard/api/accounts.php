<?php
require_once __DIR__ . '/../includes/business.php';

$q = trim($_GET['q'] ?? '');
$where = 'WHERE 1=0';
$params = [];
if ($q !== '') {
    $where = 'WHERE account_login LIKE ? OR customer_name LIKE ?';
    $like = '%' . $q . '%';
    $params = [$like, $like];
}

$stmt = db()->prepare("SELECT id, account_login, customer_name, product, expires_at, last_paid_at, created_at
                       FROM accounts $where ORDER BY id DESC LIMIT 50");
$stmt->execute($params);
$items = $stmt->fetchAll();
foreach ($items as &$item) {
    $item['status'] = account_status($item['expires_at']);
}
json_response(['ok' => true, 'items' => $items, 'amount_yuan' => RENEW_AMOUNT_YUAN]);
