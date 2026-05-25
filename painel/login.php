<?php
require_once __DIR__ . '/includes/functions.php';

if (is_logged_in()) {
    redirect('index.php');
}

$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!verify_csrf()) {
        $error = 'Token de segurança inválido. Recarregue a página.';
    } else {
        $username = trim($_POST['username'] ?? '');
        $password = $_POST['password'] ?? '';

        if (login_operator($username, $password)) {
            redirect('index.php');
        }
        $error = 'Usuário ou senha incorretos.';
    }
}
?>
<!DOCTYPE html>
<html lang="pt-BR" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login — <?= e(APP_NAME) ?></title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script>tailwind.config = { darkMode: 'class', theme: { extend: { fontFamily: { sans: ['Inter','sans-serif'] }, colors: { brand: { 500:'#6366f1',600:'#4f46e5',700:'#4338ca' } } } } };</script>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="assets/style.css">
</head>
<body class="min-h-screen bg-slate-950 font-sans text-slate-200 flex items-center justify-center p-4">
    <div class="absolute inset-0 bg-[radial-gradient(circle_at_top,_rgba(99,102,241,0.15),_transparent_55%)]"></div>
    <div class="relative w-full max-w-sm">
        <div class="mb-8 text-center">
            <div class="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-brand-600 text-white shadow-lg shadow-brand-600/30">
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
            </div>
            <h1 class="text-2xl font-bold text-white">Swift<span class="text-brand-500">IPTV</span> Panel</h1>
            <p class="mt-1 text-sm text-slate-400">Acesse o painel do operador</p>
        </div>

        <form method="post" class="rounded-2xl border border-slate-800 bg-slate-900/70 p-6 shadow-xl backdrop-blur">
            <?= csrf_field() ?>
            <?php if ($error): ?>
                <div class="mb-4 rounded-lg border border-rose-500/40 bg-rose-500/10 px-4 py-3 text-sm text-rose-300">
                    <?= e($error) ?>
                </div>
            <?php endif; ?>

            <label class="mb-1.5 block text-sm font-medium text-slate-300">Usuário</label>
            <input type="text" name="username" autofocus required
                   class="mb-4 w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white placeholder-slate-500 focus:border-brand-500 focus:ring-2 focus:ring-brand-500/30 focus:outline-none"
                   placeholder="admin">

            <label class="mb-1.5 block text-sm font-medium text-slate-300">Senha</label>
            <input type="password" name="password" required
                   class="mb-6 w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white placeholder-slate-500 focus:border-brand-500 focus:ring-2 focus:ring-brand-500/30 focus:outline-none"
                   placeholder="••••••••">

            <button type="submit"
                    class="w-full rounded-lg bg-brand-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-brand-700 focus:ring-2 focus:ring-brand-500/40 focus:outline-none">
                Entrar
            </button>
        </form>
        <p class="mt-6 text-center text-xs text-slate-600">&copy; <?= date('Y') ?> <?= e(APP_NAME) ?></p>
    </div>
</body>
</html>
