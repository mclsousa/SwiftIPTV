<?php
/**
 * Funções utilitárias compartilhadas: escape, CSRF, rate limit,
 * registro de logs e renderização do layout (sidebar + cabeçalho).
 */
require_once __DIR__ . '/db.php';
require_once __DIR__ . '/auth.php';

// ----------------------------------------------------------------------------
// Helpers básicos
// ----------------------------------------------------------------------------

/** Escapa string para saída HTML. */
function e($value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES, 'UTF-8');
}

/** Redireciona e encerra. */
function redirect(string $url): void
{
    header('Location: ' . $url);
    exit;
}

/** Retorna o IP do cliente. */
function client_ip(): string
{
    return $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
}

// ----------------------------------------------------------------------------
// CSRF
// ----------------------------------------------------------------------------

function csrf_token(): string
{
    start_session();
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function csrf_field(): string
{
    return '<input type="hidden" name="csrf_token" value="' . e(csrf_token()) . '">';
}

function verify_csrf(): bool
{
    start_session();
    $sent = $_POST['csrf_token'] ?? '';
    return !empty($_SESSION['csrf_token']) && hash_equals($_SESSION['csrf_token'], $sent);
}

/** Aborta a requisição se o token CSRF for inválido. */
function require_csrf(string $redirectOnFail): void
{
    if (!verify_csrf()) {
        flash('error', 'Token de segurança inválido. Tente novamente.');
        redirect($redirectOnFail);
    }
}

// ----------------------------------------------------------------------------
// Flash messages (toasts)
// ----------------------------------------------------------------------------

/** Define uma mensagem flash para exibir na próxima página. */
function flash(string $type, string $message): void
{
    start_session();
    $_SESSION['flash'][] = ['type' => $type, 'message' => $message];
}

/** Consome e retorna as mensagens flash. */
function take_flash(): array
{
    start_session();
    $msgs = $_SESSION['flash'] ?? [];
    unset($_SESSION['flash']);
    return $msgs;
}

// ----------------------------------------------------------------------------
// Logs de acesso (usado pela API e pelas telas)
// ----------------------------------------------------------------------------

function log_acesso(string $username, string $ip, string $userAgent, string $resultado, string $mensagem = ''): void
{
    $stmt = db()->prepare(
        'INSERT INTO logs_acesso (username, ip, user_agent, resultado, mensagem, criado_em)
         VALUES (?, ?, ?, ?, ?, NOW())'
    );
    $stmt->execute([
        mb_substr($username, 0, 191),
        mb_substr($ip, 0, 45),
        mb_substr($userAgent, 0, 255),
        $resultado === 'success' ? 'success' : 'fail',
        mb_substr($mensagem, 0, 255),
    ]);
}

// ----------------------------------------------------------------------------
// Rate limiting (por IP, usando logs_acesso)
// ----------------------------------------------------------------------------

/**
 * Retorna true se o IP estourou o limite de tentativas na janela atual.
 */
function rate_limited(string $ip): bool
{
    $stmt = db()->prepare(
        'SELECT COUNT(*) AS total FROM logs_acesso
         WHERE ip = ? AND criado_em >= (NOW() - INTERVAL ? SECOND)'
    );
    $stmt->bindValue(1, $ip);
    $stmt->bindValue(2, RATE_LIMIT_WINDOW, PDO::PARAM_INT);
    $stmt->execute();
    $total = (int) ($stmt->fetch()['total'] ?? 0);
    return $total >= RATE_LIMIT_MAX;
}

// ----------------------------------------------------------------------------
// Xtream Codes
// ----------------------------------------------------------------------------

/**
 * Valida credenciais contra um painel Xtream Codes.
 * Retorna o array user_info em caso de sucesso, ou null em falha.
 */
function xtream_validate(string $username, string $password): ?array
{
    $url = rtrim(XTREAM_URL, '/') . '/player_api.php?'
        . http_build_query(['username' => $username, 'password' => $password]);

    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT        => 8,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_USERAGENT      => 'SwiftIPTV-Panel/1.0',
    ]);
    $body = curl_exec($ch);
    curl_close($ch);

    if ($body === false) {
        return null;
    }

    $data = json_decode($body, true);
    if (!is_array($data) || empty($data['user_info'])) {
        return null;
    }

    $info = $data['user_info'];
    if ((int) ($info['auth'] ?? 0) !== 1) {
        return null;
    }

    return $info;
}

/**
 * Retorna os DNS ativos ordenados por prioridade (ASC).
 */
function dns_ativos(): array
{
    $stmt = db()->query('SELECT id, nome, url, prioridade FROM server_dns WHERE ativo = 1 ORDER BY prioridade ASC, id ASC');
    return $stmt->fetchAll();
}

// ----------------------------------------------------------------------------
// Layout (sidebar + cabeçalho)
// ----------------------------------------------------------------------------

/**
 * Renderiza o topo do layout autenticado.
 * @param string $title  título da página
 * @param string $active item ativo do menu: dashboard|dns|clientes|logs
 * @param string $base   prefixo até a raiz do painel ('' ou '../')
 */
function layout_header(string $title, string $active, string $base = ''): void
{
    $op = current_operator();
    $nav = [
        'dashboard' => ['label' => 'Dashboard', 'href' => $base . 'index.php',          'icon' => 'grid'],
        'dns'       => ['label' => 'DNS',       'href' => $base . 'dns/index.php',      'icon' => 'server'],
        'clientes'  => ['label' => 'Clientes',  'href' => $base . 'clientes/index.php', 'icon' => 'users'],
        'logs'      => ['label' => 'Logs',      'href' => $base . 'logs/index.php',     'icon' => 'list'],
    ];
    ?>
<!DOCTYPE html>
<html lang="pt-BR" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= e($title) ?> — <?= e(APP_NAME) ?></title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = {
            darkMode: 'class',
            theme: { extend: { fontFamily: { sans: ['Inter', 'sans-serif'] },
                colors: { brand: { 500: '#6366f1', 600: '#4f46e5', 700: '#4338ca' } } } }
        };
    </script>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="<?= e($base) ?>assets/style.css">
</head>
<body class="bg-slate-950 text-slate-200 font-sans antialiased">
<div class="flex min-h-screen">
    <!-- Sidebar -->
    <aside class="fixed inset-y-0 left-0 z-30 w-64 -translate-x-full lg:translate-x-0 transform bg-slate-900 border-r border-slate-800 transition-transform" id="sidebar">
        <div class="flex h-16 items-center gap-2 px-6 border-b border-slate-800">
            <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-brand-600 text-white">
                <?= icon('bolt') ?>
            </div>
            <span class="text-lg font-bold tracking-tight text-white">Swift<span class="text-brand-500">IPTV</span></span>
        </div>
        <nav class="flex flex-col gap-1 p-4">
            <?php foreach ($nav as $key => $item): ?>
                <a href="<?= e($item['href']) ?>"
                   class="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition <?= $active === $key ? 'bg-brand-600 text-white shadow-lg shadow-brand-600/20' : 'text-slate-400 hover:bg-slate-800 hover:text-white' ?>">
                    <?= icon($item['icon']) ?>
                    <?= e($item['label']) ?>
                </a>
            <?php endforeach; ?>
            <a href="<?= e($base) ?>logout.php"
               class="mt-2 flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-rose-400 transition hover:bg-rose-500/10">
                <?= icon('logout') ?> Sair
            </a>
        </nav>
        <div class="absolute bottom-0 w-full border-t border-slate-800 p-4 text-xs text-slate-500">
            Conectado como <span class="font-semibold text-slate-300"><?= e($op['username'] ?? '') ?></span>
        </div>
    </aside>

    <!-- Conteúdo -->
    <div class="flex-1 lg:ml-64">
        <header class="sticky top-0 z-20 flex h-16 items-center justify-between gap-4 border-b border-slate-800 bg-slate-950/80 px-6 backdrop-blur">
            <div class="flex items-center gap-3">
                <button onclick="document.getElementById('sidebar').classList.toggle('-translate-x-full')"
                        class="lg:hidden text-slate-400 hover:text-white"><?= icon('menu') ?></button>
                <h1 class="text-lg font-semibold text-white"><?= e($title) ?></h1>
            </div>
            <span class="rounded-full bg-slate-800 px-3 py-1 text-xs font-medium text-slate-300">
                Modo: <?= e(strtoupper(AUTH_MODE)) ?>
            </span>
        </header>
        <main class="p-6">
    <?php
}

function layout_footer(string $base = ''): void
{
    $flashes = take_flash();
    ?>
        </main>
    </div>
</div>

<!-- Toasts -->
<div id="toast-container" class="fixed bottom-5 right-5 z-50 flex flex-col gap-2"></div>
<script src="<?= e($base) ?>assets/app.js"></script>
<script>
    <?php foreach ($flashes as $f): ?>
        toast(<?= json_encode($f['type']) ?>, <?= json_encode($f['message']) ?>);
    <?php endforeach; ?>
</script>
</body>
</html>
    <?php
}

/**
 * Ícones SVG inline (stroke). Tamanho 20x20.
 */
function icon(string $name): string
{
    $paths = [
        'grid'   => '<rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/>',
        'server' => '<rect x="2" y="3" width="20" height="8" rx="2"/><rect x="2" y="13" width="20" height="8" rx="2"/><line x1="6" y1="7" x2="6.01" y2="7"/><line x1="6" y1="17" x2="6.01" y2="17"/>',
        'users'  => '<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
        'list'   => '<line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/>',
        'logout' => '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/>',
        'bolt'   => '<polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>',
        'menu'   => '<line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="18" x2="21" y2="18"/>',
        'check'  => '<polyline points="20 6 9 17 4 12"/>',
        'clock'  => '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>',
        'shield' => '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>',
    ];
    $p = $paths[$name] ?? '';
    return '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' . $p . '</svg>';
}
