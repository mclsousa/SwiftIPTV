<?php
require_once __DIR__ . '/../includes/functions.php';
require_login('../');

$base = '../';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    require_csrf('index.php');

    $nome       = trim($_POST['nome'] ?? '');
    $url        = trim($_POST['url'] ?? '');
    $ativo      = isset($_POST['ativo']) ? 1 : 0;
    $prioridade = max(0, (int) ($_POST['prioridade'] ?? 0));

    if ($nome === '' || !filter_var($url, FILTER_VALIDATE_URL)) {
        flash('error', 'Informe um nome e uma URL válida.');
        redirect('index.php');
    }

    $stmt = db()->prepare(
        'INSERT INTO server_dns (nome, url, ativo, prioridade, criado_em, atualizado_em)
         VALUES (?, ?, ?, ?, NOW(), NOW())'
    );
    $stmt->execute([$nome, $url, $ativo, $prioridade]);

    flash('success', 'DNS adicionado com sucesso.');
    redirect('index.php');
}

// Acesso direto via GET: oferece um formulário simples (fallback ao modal).
layout_header('Adicionar DNS', 'dns', $base);
?>
<div class="max-w-md rounded-xl border border-slate-800 bg-slate-900 p-6">
    <form method="post" class="space-y-4">
        <?= csrf_field() ?>
        <div>
            <label class="mb-1.5 block text-sm font-medium text-slate-300">Nome</label>
            <input type="text" name="nome" required class="w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white focus:border-brand-500 focus:outline-none">
        </div>
        <div>
            <label class="mb-1.5 block text-sm font-medium text-slate-300">URL</label>
            <input type="url" name="url" required class="w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white focus:border-brand-500 focus:outline-none">
        </div>
        <div class="flex items-center gap-4">
            <div class="flex-1">
                <label class="mb-1.5 block text-sm font-medium text-slate-300">Prioridade</label>
                <input type="number" name="prioridade" min="0" value="1" class="w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white focus:border-brand-500 focus:outline-none">
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
