# 金貔貅授权续费与盈亏大屏

全新的 PHP + MySQL 后台，用于 EA 授权、微信扫码续费、远程认证、盈亏上报和管理员大屏。

## 入口

- 游客续费列表：`/jpx_auth_pay_dashboard/index.php`
- 管理员登录：`/jpx_auth_pay_dashboard/admin/login.php`
- 账号管理：`/jpx_auth_pay_dashboard/admin/accounts.php`
- 盈亏大屏：`/jpx_auth_pay_dashboard/admin/dashboard.php`
- 安装脚本：`/jpx_auth_pay_dashboard/install.php`

默认管理员：`admin / admin123`，安装后请立刻修改密码或手动更新数据库密码哈希。

## 核心规则

- 管理员添加账号时填写：交易账号、用户、备注。
- `交易账号` 唯一，重复添加会被拒绝。
- 新账号默认未授权，付款后自动开通远程授权。
- 游客可以查看账号续费列表并扫码支付。
- 每次支付 200 元，自动延期 1 个月。
- 未到期账号从当前到期日顺延，过期账号从付款当天顺延。
- 管理员备注只在管理员页显示。

## 微信支付

配置文件：`config/wxpay.php`

当前使用微信支付 v2 Native 扫码支付，写法参考旧 `php_admin`：

```php
return [
    'enabled' => true,
    'appid' => '你的appid',
    'mch_id' => '你的商户号',
    'key' => '你的APIv2密钥',
    'notify_url' => 'https://你的域名/jpx_auth_pay_dashboard/api/wxpay_notify.php',
];
```

## EA 远程认证

接口：`api/verify.php`

建议 EA 每次启动和定时调用：

```json
{
  "account_login": "123456",
  "timestamp": "2026-06-04 12:00:00",
  "signature": "可选HMAC"
}
```

返回字段包含：

- `authorized`：是否授权
- `status`：`active / warning / expired / unpaid / not_found`
- `expires_at`：到期时间
- `days_left`：剩余天数
- `renew_warning`：到期前 3 天为 `true`

如果启用签名，请在 `config/config.php` 修改 `API_SHARED_SECRET`，签名算法：

```text
HMAC_SHA256(account_login|timestamp, API_SHARED_SECRET)
```

## EA 盈亏上报

接口：`api/trade_report.php`

建议 EA 每 1 小时上报一次：

```json
{
  "account_login": "123456",
  "timestamp": "2026-06-04 12:00:00",
  "balance": 10000,
  "equity": 9800,
  "floating_profit": -200,
  "realized_profit": 50,
  "open_positions": 6,
  "total_exposure": 2.6
}
```

成交历史接口：`api/trade_history.php`，用于后期更细的大屏统计。

## 数据库

主要表：

- `accounts`：授权账号主表
- `renew_orders`：续费支付订单
- `heartbeat_logs`：EA认证/心跳日志
- `trade_reports`：盈亏快照
- `trade_history`：成交历史

## 导入旧 build 授权数据

旧 `jinpixiu.licenses` 表按交易账号唯一导入：

```bash
php import_legacy_jinpixiu.php jinpixiu
```

导入后旧备注会作为“用户”显示，旧到期日会保留，旧授权码不再保留。

如果服务器上已经部署过早期新后台，执行下面 SQL 删除授权码字段：

```bash
mysql -u你的账号 -p jpx_auth_pay_dashboard < migrate_remove_license_codes.sql
```
