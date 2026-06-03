<?php
require_once __DIR__ . '/../includes/business.php';
require_once __DIR__ . '/../includes/auth.php';

require_admin(true);

$id = (int)($_POST['id'] ?? 0);
$accountLogin = trim($_POST['account_login'] ?? '');
$customerName = trim($_POST['customer_name'] ?? '');
$adminNote = trim($_POST['admin_note'] ?? '');

if ($id <= 0) json_response(['ok' => false, 'msg' => '账号ID错误'], 400);
if ($accountLogin === '' || $customerName === '') {
    json_response(['ok' => false, 'msg' => '账号、用户都必须填写'], 400);
}
if (!ctype_digit($accountLogin)) json_response(['ok' => false, 'msg' => '交易账号必须是数字'], 400);

try {
    $stmt = db()->prepare("UPDATE accounts
        SET account_login = ?, customer_name = ?, admin_note = ?, updated_at = NOW()
        WHERE id = ?");
    $stmt->execute([
        $accountLogin,
        $customerName,
        $adminNote !== '' ? $adminNote : null,
        $id,
    ]);
    json_response(['ok' => true]);
} catch (PDOException $e) {
    if (strpos($e->getMessage(), '1062') !== false) {
        json_response(['ok' => false, 'msg' => '该交易账号已存在，禁止重复'], 409);
    }
    json_response(['ok' => false, 'msg' => '保存失败：' . $e->getMessage()], 500);
}
