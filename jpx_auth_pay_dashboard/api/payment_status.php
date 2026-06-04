<?php
require_once __DIR__ . '/../includes/wxpay.php';

$orderNo = trim($_GET['order_no'] ?? '');
if ($orderNo === '') json_response(['ok' => false, 'msg' => '订单号不能为空'], 400);

$stmt = db()->prepare("SELECT o.*, a.expires_at
                       FROM renew_orders o
                       JOIN accounts a ON a.id = o.account_id
                       WHERE o.order_no = ?");
$stmt->execute([$orderNo]);
$order = $stmt->fetch();
if (!$order) json_response(['ok' => false, 'msg' => '订单不存在'], 404);

if ($order['status'] === 'pending') {
    try { wxpay_query_order($orderNo); } catch (Throwable $e) {}
    $stmt->execute([$orderNo]);
    $order = $stmt->fetch();
}

json_response([
    'ok' => true,
    'status' => $order['status'],
    'paid' => $order['status'] === 'paid',
    'expires_at' => $order['expires_at'],
]);
