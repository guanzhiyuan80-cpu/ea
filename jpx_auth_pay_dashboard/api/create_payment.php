<?php
require_once __DIR__ . '/../includes/wxpay.php';

$accountId = (int)($_POST['account_id'] ?? 0);
if ($accountId <= 0) json_response(['ok' => false, 'msg' => '账号参数错误'], 400);

$stmt = db()->prepare("SELECT * FROM accounts WHERE id = ?");
$stmt->execute([$accountId]);
$account = $stmt->fetch();
if (!$account) json_response(['ok' => false, 'msg' => '账号不存在'], 404);

$wxConfig = wxpay_config();
if (!wxpay_enabled($wxConfig)) {
    json_response(['ok' => false, 'msg' => '微信支付未配置，请先填写 config/wxpay.php'], 500);
}

$orderNo = 'JPX' . date('YmdHis') . random_int(1000, 9999);
$amount = (float)RENEW_AMOUNT_YUAN;

try {
    $stmt = db()->prepare("INSERT INTO renew_orders(account_id, order_no, amount_yuan, months, status, created_at)
                           VALUES(?, ?, ?, ?, 'pending', NOW())");
    $stmt->execute([$accountId, $orderNo, $amount, RENEW_MONTHS]);

    $title = '青鸾EA续费 ' . $account['account_login'];
    $pay = wxpay_create_native_order($orderNo, $amount, $title);
    if (!$pay['ok']) {
        json_response(['ok' => false, 'msg' => $pay['msg'], 'order_no' => $orderNo], 500);
    }
    db()->prepare("UPDATE renew_orders SET code_url = ?, updated_at = NOW() WHERE order_no = ?")
        ->execute([$pay['code_url'], $orderNo]);

    json_response([
        'ok' => true,
        'order_no' => $orderNo,
        'amount_yuan' => $amount,
        'code_url' => $pay['code_url'],
    ]);
} catch (Throwable $e) {
    json_response(['ok' => false, 'msg' => '创建支付订单失败：' . $e->getMessage()], 500);
}
