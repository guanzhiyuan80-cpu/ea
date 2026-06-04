<?php
// WeChat Pay v2 Native pay config.
// Put real merchant secrets in wxpay.local.php. That file is ignored by Git.
$config = [
    'enabled' => false,
    'appid' => '',
    'mch_id' => '',
    'key' => '',
    'api_url' => 'https://api.mch.weixin.qq.com/pay/unifiedorder',
    'query_url' => 'https://api.mch.weixin.qq.com/pay/orderquery',
    'notify_url' => 'https://your-domain.com/jpx_auth_pay_dashboard/api/wxpay_notify.php',
];

$local = __DIR__ . '/wxpay.local.php';
if (is_file($local)) {
    $override = require $local;
    if (is_array($override)) {
        $config = array_merge($config, $override);
    }
}

return $config;
