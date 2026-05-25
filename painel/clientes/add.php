<?php
require_once __DIR__ . '/../includes/functions.php';
require_login('../');

$base = '../';

if (AUTH_MODE !== 'local') {
    flash('error', 'Clientes são gerenciados pelo painel Xtream neste modo.');
    redirect('index.php');
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    require_csrf('index.php');

    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';
    $ativo    = isset($_POST['ativo']) ? 1 : 0;
    $expira   = trim($_POST['expira_em'] ?? '');
    $expira   = $expira !== '' ? $expira : null;

    if ($username === '' || $password === '') {
        flash('error', 'Usuário e senha são obrigatórios.');
        redirect('add.php');
    }

    // Verifica duplicidade
    $check = db()->prepare('SELECT id FROM clientes WHERE username = ? LIMIT 1');
    $check->execute([$username]);
    if ($check->fetch()) {
        flash('error', 'Já existe um cliente com esse usuário.');
        redirect('add.php');
    }

    $stmt = db()->prepare(
        'INSERT INTO clientes (username, password_hash, ativo, expira_em, criado_em)
         VALUES (?, ?, ?, ?, NOW())'
    );
    $stmt->execute([$username, password_hash($password, PASSWORD_BCRYPT), $ativo, $expira]);

    flash('success', 'Cliente criado com sucesso.');
    redirect('index.php');
}

layout_header('Adicionar Cliente', 'clientes', $base);
?>
<div class="max-w-md rounded-xl border border-slate-800 bg-slate-900 p-6">
    <form method="post" class="space-y-4">
        <?= csrf_field() ?>
        <div>
            <label class="mb-1.5 block text-sm font-medium text-slate-300">Usuário</label>
            <input type="text" name="username" required class="w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white focus:border-brand-500 focus:outline-none">
        </div>
        <div>
            <label class="mb-1.5 block text-sm font-medium text-slate-300">Senha</label>
            <input type="text" name="password" required class="w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white focus:border-brand-500 focus:outline-none">
        </div>
        <div class="flex items-center gap-4">
            <div class="flex-1">
                <label class="mb-1.5 block text-sm font-medium text-slate-300">Expira em</label>
                <input type="date" name="expira_em" class="w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white focus:border-brand-500 focus:outline-none [color-scheme:dark]">
            </div>
            <label class="mt-6 flex items-center gap-2 text-sm text-slate-300">
                <input type="checkbox" name="ativo" checked class="h-4 w-4 rounded border-slate-600 bg-slate-800 text-brand-600"> Ativo
            </label>
        </div>
        <div class="flex justify-end gap-2 pt-2">
            <a href="index.php" class="rounded-lg px-4 py-2.5 text-sm font-medium text-slate-300 hover:bg-slate-800">Voltar</a>
            <button type="submit" class="rounded-lg bg-brand-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-brand-700">Salvar</button>
        </div>
    </form>
</div>
<?php layout_footer($base); ?>
