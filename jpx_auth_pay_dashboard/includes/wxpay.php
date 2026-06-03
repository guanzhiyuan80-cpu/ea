<?php
require_once __DIR__ . '/business.php';

function wxpay_config(): array {
    return require __DIR__ . '/../config/wxpay.php';
}

function wxpay_enabled(array $config): bool {
    return !empty($config['enabled']) && !empty($config['appid']) && !empty($config['mch_id']) && !empty($config['key']);
}

function wxpay_create_native_order(string $orderNo, float $amountYuan, string $body): array {
    $config = wxpay_config();
    if (!wxpay_enabled($config)) {
        return ['ok' => false, 'msg' => '微信支付未配置，请先填写 config/wxpay.php'];
    }

    $params = [
        'appid' => $config['appid'],
        'mch_id' => $config['mch_id'],
        'nonce_str' => wxpay_nonce(),
        'body' => $body,
        'out_trade_no' => $orderNo,
        'total_fee' => (int)round($amountYuan * 100),
        'spbill_create_ip' => $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1',
        'notify_url' => $config['notify_url'],
        'trade_type' => 'NATIVE',
        'product_id' => 'jpx_renew_' . $orderNo,
    ];
    $params['sign'] = wxpay_sign($params, $config['key']);

    $resp = wxpay_post_xml(wxpay_array_to_xml($params), $config['api_url']);
    $data = wxpay_xml_to_array($resp);
    if (($data['return_code'] ?? '') === 'SUCCESS' && ($data['result_code'] ?? '') === 'SUCCESS') {
        return ['ok' => true, 'code_url' => $data['code_url'] ?? '', 'raw' => $data];
    }
    return ['ok' => false, 'msg' => $data['return_msg'] ?? $data['err_code_des'] ?? '微信下单失败', 'raw' => $data];
}

function wxpay_query_order(string $orderNo): array {
    $config = wxpay_config();
    if (!wxpay_enabled($config)) return ['ok' => false, 'msg' => '微信支付未配置'];

    $params = [
        'appid' => $config['appid'],
        'mch_id' => $config['mch_id'],
        'out_trade_no' => $orderNo,
        'nonce_str' => wxpay_nonce(),
    ];
    $params['sign'] = wxpay_sign($params, $config['key']);
    $resp = wxpay_post_xml(wxpay_array_to_xml($params), $config['query_url']);
    $data = wxpay_xml_to_array($resp);

    if (($data['return_code'] ?? '') === 'SUCCESS' && ($data['result_code'] ?? '') === 'SUCCESS') {
        if (($data['trade_state'] ?? '') === 'SUCCESS') {
            complete_paid_order($orderNo, $data['transaction_id'] ?? '');
        }
        return ['ok' => true, 'data' => $data];
    }
    return ['ok' => false, 'msg' => $data['return_msg'] ?? $data['err_code_des'] ?? '微信查单失败', 'data' => $data];
}

function wxpay_verify_sign(array $data): bool {
    $config = wxpay_config();
    if (empty($data['sign']) || empty($config['key'])) return false;
    $sign = $data['sign'];
    unset($data['sign']);
    return hash_equals($sign, wxpay_sign($data, $config['key']));
}

function wxpay_sign(array $params, string $key): string {
    $params = array_filter($params, fn($v) => $v !== '' && $v !== null);
    unset($params['sign']);
    ksort($params);
    $string = urldecode(http_build_query($params)) . '&key=' . $key;
    return strtoupper(md5($string));
}

function wxpay_nonce(int $length = 32): string {
    $chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    $out = '';
    for ($i = 0; $i < $length; $i++) $out .= $chars[random_int(0, strlen($chars) - 1)];
    return $out;
}

function wxpay_array_to_xml(array $arr): string {
    $xml = '<xml>';
    foreach ($arr as $key => $val) $xml .= '<' . $key . '><![CDATA[' . $val . ']]></' . $key . '>';
    return $xml . '</xml>';
}

function wxpay_xml_to_array(string $xml): array {
    if (trim($xml) === '') return [];
    $obj = simplexml_load_string($xml, 'SimpleXMLElement', LIBXML_NOCDATA);
    return $obj ? json_decode(json_encode($obj), true) : [];
}

function wxpay_post_xml(string $xml, string $url): string {
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL => $url,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => $xml,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
        CURLOPT_TIMEOUT => 30,
    ]);
    $resp = curl_exec($ch);
    if ($resp === false) {
        $err = curl_error($ch);
        curl_close($ch);
        throw new RuntimeException('微信请求失败：' . $err);
    }
    curl_close($ch);
    return $resp;
}
