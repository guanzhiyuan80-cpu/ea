<?php
require_once __DIR__ . '/../includes/wxpay.php';

$xml = file_get_contents('php://input');
$data = wxpay_xml_to_array($xml ?: '');

if (!$data || !wxpay_verify_sign($data)) {
    echo wxpay_array_to_xml(['return_code' => 'FAIL', 'return_msg' => 'SIGNERROR']);
    exit;
}

if (($data['return_code'] ?? '') === 'SUCCESS' && ($data['result_code'] ?? '') === 'SUCCESS') {
    $orderNo = $data['out_trade_no'] ?? '';
    if ($orderNo !== '') {
        try {
            db()->prepare("UPDATE renew_orders SET notify_raw = ? WHERE order_no = ?")->execute([$xml, $orderNo]);
            complete_paid_order($orderNo, $data['transaction_id'] ?? '');
        } catch (Throwable $e) {
            error_log('wxpay notify failed: ' . $e->getMessage());
            echo wxpay_array_to_xml(['return_code' => 'FAIL', 'return_msg' => 'PROCESSFAIL']);
            exit;
        }
    }
}
echo wxpay_array_to_xml(['return_code' => 'SUCCESS', 'return_msg' => 'OK']);
