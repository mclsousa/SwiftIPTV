<?php
/**
 * Endpoint de autenticação consumido pelo app Windows.
 *
 * POST application/json  ->  { "username": "x", "password": "y" }
 *
 * Sucesso:
 * {
 *   "ok": true,
 *   "token": "<sha256>",
 *   "server_dns": ["http://servidor1.com", ...],
 *   "username_iptv": "...",
 *   "password_iptv": "...",
 *   "expires_at": "2025-12-31"
 * }
 * Falha:
 * { "ok": false, "message": "..." }
 */
require_once __DIR__ . '/../includes/functions.php';

// ----------------------------------------------------------------------------
// Cabeçalhos (CORS restrito + JSON)
// ----------------------------------------------------------------------------
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: ' . API_ALLOWED_ORIGIN);
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('X-Content-Type-Options: nosniff');

// Preflight
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

/** Resposta padronizada e encerramento. */
function api_respond(array $payload, int $status = 200): void
{
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

$ip        = client_ip();
$userAgent = $_SERVER['HTTP_USER_AGENT'] ?? 'desconhecido';

// ----------------------------------------------------------------------------
// 1. Apenas POST com Content-Type application/json
// ----------------------------------------------------------------------------
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    api_respond(['ok' => false, 'message' => 'Método não permitido'], 405);
}
$contentType = $_SERVER['CONTENT_TYPE'] ?? '';
if (stripos($contentType, 'application/json') === false) {
    api_respond(['ok' => false, 'message' => 'Content-Type deve ser application/json'], 415);
}

// ----------------------------------------------------------------------------
// 2. Rate limiting (antes de processar)
// ----------------------------------------------------------------------------
if (rate_limited($ip)) {
    log_acesso('-', $ip, $userAgent, 'fail', 'Rate limit excedido');
    api_respond(['ok' => false, 'message' => 'Muitas tentativas. Aguarde um instante.'], 429);
}

// ----------------------------------------------------------------------------
// 3. Ler corpo JSON
// ----------------------------------------------------------------------------
$raw  = file_get_contents('php://input');
$body = json_decode($raw, true);
if (!is_array($body)) {
    log_acesso('-', $ip, $userAgent, 'fail', 'JSON inválido');
    api_respond(['ok' => false, 'message' => 'Corpo JSON inválido'], 400);
}

$username = trim((string) ($body['username'] ?? ''));
$password = (string) ($body['password'] ?? '');

if ($username === '' || $password === '') {
    log_acesso($username !== '' ? $username : '-', $ip, $userAgent, 'fail', 'Campos ausentes');
    api_respond(['ok' => false, 'message' => 'Usuário e senha são obrigatórios']);
}

// ----------------------------------------------------------------------------
// 4/5. Validação conforme AUTH_MODE
// ----------------------------------------------------------------------------
$valido        = false;
$username_iptv = $username;
$password_iptv = $password;
$expires_at    = null;
$falhaMsg      = 'Usuário ou senha incorretos';

if (AUTH_MODE === 'xtream') {
    $info = xtream_validate($username, $password);
    if ($info !== null) {
        $valido        = true;
        $username_iptv = $info['username'] ?? $username;
        $password_iptv = $info['password'] ?? $password;
        if (!empty($info['exp_date'])) {
            $expires_at = date('Y-m-d', (int) $info['exp_date']); // exp_date é timestamp unix
        }
    }
} else { // local
    $stmt = db()->prepare('SELECT * FROM clientes WHERE username = ? LIMIT 1');
    $stmt->execute([$username]);
    $cliente = $stmt->fetch();

    if ($cliente && password_verify($password, $cliente['password_hash'])) {
        if (!$cliente['ativo']) {
            $falhaMsg = 'Cliente inativo';
        } elseif ($cliente['expira_em'] !== null && $cliente['expira_em'] < date('Y-m-d')) {
            $falhaMsg = 'Assinatura expirada';
        } else {
            $valido        = true;
            $username_iptv = $cliente['username'];
            $password_iptv = $password;
            $expires_at    = $cliente['expira_em'];
            // Atualiza último acesso
            db()->prepare('UPDATE clientes SET ultimo_acesso = NOW() WHERE id = ?')->execute([$cliente['id']]);
        }
    }
}

// ----------------------------------------------------------------------------
// 7. Registrar acesso (sempre)
// ----------------------------------------------------------------------------
if (!$valido) {
    log_acesso($username, $ip, $userAgent, 'fail', $falhaMsg);
    api_respond(['ok' => false, 'message' => $falhaMsg], 401);
}

// ----------------------------------------------------------------------------
// 6. Buscar DNS ativos ordenados por prioridade ASC
// ----------------------------------------------------------------------------
$server_dns = array_map(fn($d) => $d['url'], dns_ativos());

// Token único
$token = hash('sha256', $username . '|' . $ip . '|' . microtime(true) . '|' . SECRET_KEY . '|' . bin2hex(random_bytes(16)));

log_acesso($username, $ip, $userAgent, 'success', 'Login OK (' . AUTH_MODE . ')');

// ----------------------------------------------------------------------------
// 8. Resposta de sucesso
// ----------------------------------------------------------------------------
api_respond([
    'ok'            => true,
    'token'         => $token,
    'server_dns'    => $server_dns,
    'username_iptv' => $username_iptv,
    'password_iptv' => $password_iptv,
    'expires_at'    => $expires_at,
]);
