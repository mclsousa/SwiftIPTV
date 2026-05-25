<?php
/**
 * Testa se uma URL responde e mede a latência.
 * Recebe POST: url (e csrf_token quando chamado pelo painel).
 * Retorna JSON: { ok: bool, ms: int }
 */
require_once __DIR__ . '/../includes/functions.php';
require_login('../');

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['ok' => false, 'message' => 'Método inválido']);
    exit;
}

// Chamadas vindas do painel enviam CSRF; validamos quando presente.
if (isset($_POST['csrf_token']) && !verify_csrf()) {
    echo json_encode(['ok' => false, 'message' => 'CSRF inválido']);
    exit;
}

$url = trim($_POST['url'] ?? '');
if (!filter_var($url, FILTER_VALIDATE_URL)) {
    echo json_encode(['ok' => false, 'message' => 'URL inválida']);
    exit;
}

$start = microtime(true);

$ch = curl_init($url);
curl_setopt_array($ch, [
    CURLOPT_NOBODY         => false,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT        => 5,        // timeout total de 5s
    CURLOPT_CONNECTTIMEOUT => 5,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_SSL_VERIFYPEER => false,
    CURLOPT_SSL_VERIFYHOST => 0,
    CURLOPT_USERAGENT      => 'SwiftIPTV-Panel/1.0 (ping)',
]);
curl_exec($ch);
$errno    = curl_errno($ch);
$httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

$ms = (int) round((microtime(true) - $start) * 1000);

// Considera OK se houve resposta HTTP (qualquer código) sem erro de conexão/timeout.
$ok = ($errno === 0 && $httpCode > 0);

echo json_encode(['ok' => $ok, 'ms' => $ms, 'http' => $httpCode]);
