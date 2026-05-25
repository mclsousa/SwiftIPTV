<?php
require_once __DIR__ . '/../includes/functions.php';
require_login('../');

$base = '../';
$pdo  = db();
$id   = (int) ($_GET['id'] ?? $_POST['id'] ?? 0);

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    require_csrf('index.php');

    $nome       = trim($_POST['nome'] ?? '');
    $url        = trim($_POST['url'] ?? '');
    $ativo      = isset($_POST['ativo']) ? 1 : 0;
    $prioridade = max(0, (int) ($_POST['prioridade'] ?? 0));

    if ($nome === '' || !filter_var($url, FILTER_VALIDATE_URL)) {
        flash('error', 'Informe um nome e uma URL válida.');
        redirect('edit.php?id=' . $id);
    }

    $stmt = $pdo->prepare(
        'UPDATE server_dns SET nome = ?, url = ?, ativo = ?, prioridade = ?, atualizado_em = NOW() WHERE id = ?'
    );
    $stmt->execute([$nome, $url, $ativo, $prioridade, $id]);

    flash('success', 'DNS atualizado.');
    redirect('index.php');
}

$stmt = $pdo->prepare('SELECT * FROM server_dns WHERE id = ? LIMIT 1');
$stmt->execute([$id]);
$dns = $stmt->fetch();

if (!$dns) {
    flash('error', 'DNS não encontrado.');
    redirect('index.php');
}

layout_header('Editar DNS', 'dns', $base);
?>
<div class="max-w-md rounded-xl border border-slate-800 bg-slate-900 p-6">
    <form method="post" class="space-y-4">
        <?= csrf_field() ?>
        <input type="hidden" name="id" value="<?= (int) $dns['id'] ?>">
        <div>
            <label class="mb-1.5 block text-sm font-medium text-slate-300">Nome</label>
            <input type="text" name="nome" required value="<?= e($dns['nome']) ?>" class="w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white focus:border-brand-500 focus:outline-none">
        </div>
        <div>
            <label class="mb-1.5 block text-sm font-medium text-slate-300">URL</label>
            <input type="url" name="url" required value="<?= e($dns['url']) ?>" class="w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white focus:border-brand-500 focus:outline-none">
        </div>
        <div class="flex items-center gap-4">
            <div class="flex-1">
                <label class="mb-1.5 block text-sm font-medium text-slate-300">Prioridade</label>
                <input type="number" name="prioridade" min="0" value="<?= (int) $dns['prioridade'] ?>" class="w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white focus:border-brand-500 focus:outline-none">
            </div>
            <label class="mt-6 flex items-center gap-2 text-sm text-slate-300">
                <input type="checkbox" name="ativo" <?= $dns['ativo'] ? 'checked' : '' ?> class="h-4 w-4 rounded border-slate-600 bg-slate-800 text-brand-600"> Ativo
            </label>
        </div>
        <div class="flex justify-end gap-2 pt-2">
            <a href="index.php" class="rounded-lg px-4 py-2.5 text-sm font-medium text-slate-300 hover:bg-slate-800">Voltar</a>
            <button type="submit" class="rounded-lg bg-brand-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-brand-700">Salvar alterações</button>
        </div>
    </form>
</div>
<?php layout_footer($base); ?>
