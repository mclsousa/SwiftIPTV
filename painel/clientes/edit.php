<?php
require_once __DIR__ . '/../includes/functions.php';
require_login('../');

$base = '../';
$pdo  = db();

if (AUTH_MODE !== 'local') {
    flash('error', 'Clientes são gerenciados pelo painel Xtream neste modo.');
    redirect('index.php');
}

$id = (int) ($_GET['id'] ?? $_POST['id'] ?? 0);

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    require_csrf('index.php');

    $username = trim($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';
    $ativo    = isset($_POST['ativo']) ? 1 : 0;
    $expira   = trim($_POST['expira_em'] ?? '');
    $expira   = $expira !== '' ? $expira : null;

    if ($username === '') {
        flash('error', 'O usuário é obrigatório.');
        redirect('edit.php?id=' . $id);
    }

    if ($password !== '') {
        $stmt = $pdo->prepare('UPDATE clientes SET username = ?, password_hash = ?, ativo = ?, expira_em = ? WHERE id = ?');
        $stmt->execute([$username, password_hash($password, PASSWORD_BCRYPT), $ativo, $expira, $id]);
    } else {
        $stmt = $pdo->prepare('UPDATE clientes SET username = ?, ativo = ?, expira_em = ? WHERE id = ?');
        $stmt->execute([$username, $ativo, $expira, $id]);
    }

    flash('success', 'Cliente atualizado.');
    redirect('index.php');
}

$stmt = $pdo->prepare('SELECT * FROM clientes WHERE id = ? LIMIT 1');
$stmt->execute([$id]);
$cliente = $stmt->fetch();

if (!$cliente) {
    flash('error', 'Cliente não encontrado.');
    redirect('index.php');
}

layout_header('Editar Cliente', 'clientes', $base);
?>
<div class="max-w-md rounded-xl border border-slate-800 bg-slate-900 p-6">
    <form method="post" class="space-y-4">
        <?= csrf_field() ?>
        <input type="hidden" name="id" value="<?= (int) $cliente['id'] ?>">
        <div>
            <label class="mb-1.5 block text-sm font-medium text-slate-300">Usuário</label>
            <input type="text" name="username" required value="<?= e($cliente['username']) ?>" class="w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white focus:border-brand-500 focus:outline-none">
        </div>
        <div>
            <label class="mb-1.5 block text-sm font-medium text-slate-300">Nova senha <span class="text-slate-500">(deixe em branco para manter)</span></label>
            <input type="text" name="password" class="w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white focus:border-brand-500 focus:outline-none">
        </div>
        <div class="flex items-center gap-4">
            <div class="flex-1">
                <label class="mb-1.5 block text-sm font-medium text-slate-300">Expira em</label>
                <input type="date" name="expira_em" value="<?= $cliente['expira_em'] ? e($cliente['expira_em']) : '' ?>" class="w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white focus:border-brand-500 focus:outline-none [color-scheme:dark]">
            </div>
            <label class="mt-6 flex items-center gap-2 text-sm text-slate-300">
                <input type="checkbox" name="ativo" <?= $cliente['ativo'] ? 'checked' : '' ?> class="h-4 w-4 rounded border-slate-600 bg-slate-800 text-brand-600"> Ativo
            </label>
        </div>
        <div class="flex justify-end gap-2 pt-2">
            <a href="index.php" class="rounded-lg px-4 py-2.5 text-sm font-medium text-slate-300 hover:bg-slate-800">Voltar</a>
            <button type="submit" class="rounded-lg bg-brand-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-brand-700">Salvar alterações</button>
        </div>
    </form>
</div>
<?php layout_footer($base); ?>
