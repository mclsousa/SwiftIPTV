<?php
require_once __DIR__ . '/../includes/functions.php';
require_login('../');

$base = '../';
$pdo  = db();

// ----------------------------------------------------------------------------
// Ações (somente modo local)
// ----------------------------------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] === 'POST' && AUTH_MODE === 'local') {
    require_csrf('index.php');
    $action = $_POST['action'] ?? '';
    $id     = (int) ($_POST['id'] ?? 0);

    if ($action === 'toggle') {
        $pdo->prepare('UPDATE clientes SET ativo = 1 - ativo WHERE id = ?')->execute([$id]);
        flash('success', 'Status do cliente atualizado.');
    } elseif ($action === 'delete') {
        $pdo->prepare('DELETE FROM clientes WHERE id = ?')->execute([$id]);
        flash('success', 'Cliente removido.');
    }
    redirect('index.php');
}

layout_header('Clientes', 'clientes', $base);

// ----------------------------------------------------------------------------
// Modo Xtream: apenas aviso
// ----------------------------------------------------------------------------
if (AUTH_MODE === 'xtream'):
?>
<div class="rounded-xl border border-amber-500/30 bg-amber-500/10 p-6">
    <div class="flex items-start gap-3">
        <span class="text-amber-400"><?= icon('shield') ?></span>
        <div>
            <h2 class="font-semibold text-amber-300">Usuários gerenciados pelo painel Xtream</h2>
            <p class="mt-1 text-sm text-amber-200/70">
                O painel está configurado em <strong>modo Xtream Codes</strong> (<code class="rounded bg-slate-800 px-1.5 py-0.5"><?= e(XTREAM_URL) ?></code>).
                A criação, edição e expiração de clientes deve ser feita diretamente no painel Xtream.
                Aqui apenas validamos o login e entregamos os DNS ativos ao app.
            </p>
            <p class="mt-2 text-sm text-amber-200/70">
                Para gerenciar clientes localmente, altere <code class="rounded bg-slate-800 px-1.5 py-0.5">AUTH_MODE</code> para <code class="rounded bg-slate-800 px-1.5 py-0.5">'local'</code> em <code class="rounded bg-slate-800 px-1.5 py-0.5">config.php</code>.
            </p>
        </div>
    </div>
</div>
<?php
layout_footer($base);
exit;
endif;

// ----------------------------------------------------------------------------
// Modo Local: CRUD completo
// ----------------------------------------------------------------------------
$clientes = $pdo->query('SELECT * FROM clientes ORDER BY id DESC')->fetchAll();
$hoje = date('Y-m-d');
?>
<div class="mb-5 flex items-center justify-between">
    <p class="text-sm text-slate-400">Clientes autenticados pelo banco local do painel.</p>
    <a href="add.php" class="inline-flex items-center gap-2 rounded-lg bg-brand-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-brand-700">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        Adicionar Cliente
    </a>
</div>

<div class="overflow-hidden rounded-xl border border-slate-800 bg-slate-900">
    <table class="w-full text-sm">
        <thead class="bg-slate-800/50 text-xs uppercase tracking-wide text-slate-400">
            <tr>
                <th class="px-4 py-3 text-left font-medium">Usuário</th>
                <th class="px-4 py-3 text-left font-medium">Status</th>
                <th class="px-4 py-3 text-left font-medium">Expira em</th>
                <th class="px-4 py-3 text-left font-medium">Último acesso</th>
                <th class="px-4 py-3 text-left font-medium">Criado em</th>
                <th class="px-4 py-3 text-right font-medium">Ações</th>
            </tr>
        </thead>
        <tbody class="divide-y divide-slate-800">
            <?php if (!$clientes): ?>
                <tr><td colspan="6" class="px-4 py-10 text-center text-slate-500">Nenhum cliente cadastrado.</td></tr>
            <?php endif; ?>
            <?php foreach ($clientes as $c):
                $expirado = $c['expira_em'] !== null && $c['expira_em'] < $hoje;
                if (!$c['ativo'])      { $badge = ['bg-slate-600/30','text-slate-400','Inativo','bg-slate-400']; }
                elseif ($expirado)     { $badge = ['bg-rose-500/15','text-rose-400','Expirado','bg-rose-400']; }
                else                   { $badge = ['bg-emerald-500/15','text-emerald-400','Ativo','bg-emerald-400']; }
            ?>
                <tr class="odd:bg-slate-900 even:bg-slate-900/40 hover:bg-slate-800/60">
                    <td class="px-4 py-3 font-medium text-white"><?= e($c['username']) ?></td>
                    <td class="px-4 py-3">
                        <span class="inline-flex items-center gap-1.5 rounded-full <?= $badge[0] ?> px-2.5 py-0.5 text-xs font-medium <?= $badge[1] ?>">
                            <span class="h-1.5 w-1.5 rounded-full <?= $badge[3] ?>"></span> <?= $badge[2] ?>
                        </span>
                    </td>
                    <td class="px-4 py-3 text-slate-400"><?= $c['expira_em'] ? e(date('d/m/Y', strtotime($c['expira_em']))) : '<span class="text-slate-600">sem expiração</span>' ?></td>
                    <td class="px-4 py-3 text-slate-400"><?= $c['ultimo_acesso'] ? e(date('d/m/Y H:i', strtotime($c['ultimo_acesso']))) : '—' ?></td>
                    <td class="px-4 py-3 text-slate-400"><?= e(date('d/m/Y', strtotime($c['criado_em']))) ?></td>
                    <td class="px-4 py-3">
                        <div class="flex items-center justify-end gap-1.5">
                            <a href="edit.php?id=<?= (int) $c['id'] ?>" class="rounded-md bg-slate-700/50 px-2.5 py-1.5 text-xs font-medium text-slate-300 hover:bg-slate-700">Editar</a>
                            <form method="post" class="inline">
                                <?= csrf_field() ?>
                                <input type="hidden" name="action" value="toggle">
                                <input type="hidden" name="id" value="<?= (int) $c['id'] ?>">
                                <button type="submit" class="rounded-md bg-amber-500/15 px-2.5 py-1.5 text-xs font-medium text-amber-400 hover:bg-amber-500/25"><?= $c['ativo'] ? 'Desativar' : 'Ativar' ?></button>
                            </form>
                            <form method="post" class="inline" onsubmit="return confirm('Remover este cliente?');">
                                <?= csrf_field() ?>
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="id" value="<?= (int) $c['id'] ?>">
                                <button type="submit" class="rounded-md bg-rose-500/15 px-2.5 py-1.5 text-xs font-medium text-rose-400 hover:bg-rose-500/25">Deletar</button>
                            </form>
                        </div>
                    </td>
                </tr>
            <?php endforeach; ?>
        </tbody>
    </table>
</div>

<?php layout_footer($base); ?>
