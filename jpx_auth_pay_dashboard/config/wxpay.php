<?php
// WeChat Pay v2 Native pay config.
// You can copy values from the old php_admin/config/wxpay_config.php when deploying.
return [
    'enabled' => false,
    'appid' => '',
    'mch_id' => '',
    'key' => '',
    'api_url' => 'https://api.mch.weixin.qq.com/pay/unifiedorder',
    'query_url' => 'https://api.mch.weixin.qq.com/pay/orderquery',
    'notify_url' => 'https://your-domain.com/jpx_auth_pay_dashboard/api/wxpay_notify.php',
];
