<?php
/**
 * Sessão e autenticação do OPERADOR (admin do painel).
 */
require_once __DIR__ . '/db.php';

/**
 * Inicia a sessão com nome e cookie params seguros.
 */
function start_session(): void
{
    if (session_status() === PHP_SESSION_ACTIVE) {
        return;
    }

    session_name(SESSION_NAME);
    session_set_cookie_params([
        'lifetime' => 0,
        'path'     => '/',
        'httponly' => true,
        'samesite' => 'Lax',
        'secure'   => (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off'),
    ]);
    session_start();
}

function is_logged_in(): bool
{
    start_session();
    return !empty($_SESSION['operador_id']);
}

function current_operator(): ?array
{
    if (!is_logged_in()) {
        return null;
    }
    return [
        'id'       => $_SESSION['operador_id'],
        'username' => $_SESSION['operador_username'] ?? '',
    ];
}

/**
 * Tenta autenticar o operador. Retorna true em caso de sucesso.
 */
function login_operator(string $username, string $password): bool
{
    start_session();

    $stmt = db()->prepare('SELECT id, username, password_hash FROM operadores WHERE username = ? LIMIT 1');
    $stmt->execute([$username]);
    $op = $stmt->fetch();

    if (!$op || !password_verify($password, $op['password_hash'])) {
        return false;
    }

    // Regenera o ID de sessão para evitar session fixation.
    session_regenerate_id(true);

    $_SESSION['operador_id']       = (int) $op['id'];
    $_SESSION['operador_username'] = $op['username'];

    return true;
}

function logout_operator(): void
{
    start_session();
    $_SESSION = [];
    if (ini_get('session.use_cookies')) {
        $params = session_get_cookie_params();
        setcookie(session_name(), '', time() - 42000, $params['path'], $params['domain'] ?? '', $params['secure'], $params['httponly']);
    }
    session_destroy();
}

/**
 * Protege uma página. Se não estiver logado, redireciona para o login.
 * @param string $base prefixo até a raiz do painel ('' ou '../')
 */
function require_login(string $base = ''): void
{
    if (!is_logged_in()) {
        header('Location: ' . $base . 'login.php');
        exit;
    }
}
