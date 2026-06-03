<?php
require_once __DIR__ . '/../config/config.php';

if (session_status() === PHP_SESSION_NONE) {
    session_name(SESSION_NAME);
    session_set_cookie_params([
        'lifetime' => 0,
        'path' => '/',
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
    session_start();
}

function current_admin(): ?array {
    if (empty($_SESSION['admin_id'])) return null;
    return [
        'id' => (int)$_SESSION['admin_id'],
        'username' => (string)$_SESSION['admin_username'],
    ];
}

function require_admin(bool $api = false): array {
    $admin = current_admin();
    if ($admin) return $admin;
    if ($api) json_response(['ok' => false, 'msg' => '请先登录管理员账号'], 401);
    header('Location: login.php');
    exit;
}

function login_admin(int $id, string $username): void {
    session_regenerate_id(true);
    $_SESSION['admin_id'] = $id;
    $_SESSION['admin_username'] = $username;
}

function logout_admin(): void {
    $_SESSION = [];
    if (ini_get('session.use_cookies')) {
        $p = session_get_cookie_params();
        setcookie(session_name(), '', time() - 3600, $p['path'], $p['domain'] ?? '', $p['secure'] ?? false, $p['httponly'] ?? true);
    }
    session_destroy();
}
