<?php
require_once __DIR__ . '/../includes/functions.php';
require_login('../');

$pdo  = db();
$base = '../';

// ----------------------------------------------------------------------------
// Ações (POST)
// ----------------------------------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';
    $isAjax = ($action === 'reorder' || $action === 'set_priority');

    if (!verify_csrf()) {
        if ($isAjax) {
            header('Content-Type: application/json');
            echo json_encode(['ok' => false, 'message' => 'CSRF inválido']);
            exit;
        }
        flash('error', 'Token de segurança inválido.');
        redirect('index.php');
    }

    switch ($action) {
        case 'toggle':
            $id = (int) ($_POST['id'] ?? 0);
            $pdo->prepare('UPDATE server_dns SET ativo = 1 - ativo, atualizado_em = NOW() WHERE id = ?')->execute([$id]);
            flash('success', 'Status do DNS atualizado.');
            redirect('index.php');
            break;

        case 'delete':
            $id = (int) ($_POST['id'] ?? 0);
            $pdo->prepare('DELETE FROM server_dns WHERE id = ?')->execute([$id]);
            flash('success', 'DNS removido.');
            redirect('index.php');
            break;

        case 'set_priority':
            $id  = (int) ($_POST['id'] ?? 0);
            $pri = max(0, (int) ($_POST['prioridade'] ?? 0));
            $pdo->prepare('UPDATE server_dns SET prioridade = ?, atualizado_em = NOW() WHERE id = ?')->execute([$pri, $id]);
            header('Content-Type: application/json');
            echo json_encode(['ok' => true]);
            exit;

        case 'reorder':
            $ids = json_decode($_POST['order'] ?? '[]', true);
            if (is_array($ids)) {
                $stmt = $pdo->prepare('UPDATE server_dns SET prioridade = ?, atualizado_em = NOW() WHERE id = ?');
                foreach (array_values($ids) as $pos => $id) {
                    $stmt->execute([$pos + 1, (int) $id]);
                }
            }
            header('Content-Type: application/json');
            echo json_encode(['ok' => true]);
            exit;
    }
}

$dnsList = $pdo->query('SELECT * FROM server_dns ORDER BY prioridade ASC, id ASC')->fetchAll();

layout_header('Servidores DNS', 'dns', $base);
?>

<div class="mb-5 flex items-center justify-between">
    <p class="text-sm text-slate-400">Gerencie e ordene as URLs entregues ao app. Arraste pelas linhas para reordenar a prioridade.</p>
    <button onclick="openModal()"
            class="inline-flex items-center gap-2 rounded-lg bg-brand-600 px-4 py-2.5 text-sm font-semibold text-white transition hover:bg-brand-700">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        Adicionar DNS
    </button>
</div>

<div class="overflow-hidden rounded-xl border border-slate-800 bg-slate-900">
    <table class="w-full text-sm">
        <thead class="bg-slate-800/50 text-xs uppercase tracking-wide text-slate-400">
            <tr>
                <th class="px-4 py-3 text-left font-medium">Prio.</th>
                <th class="px-4 py-3 text-left font-medium">Nome</th>
                <th class="px-4 py-3 text-left font-medium">URL</th>
                <th class="px-4 py-3 text-left font-medium">Status</th>
                <th class="px-4 py-3 text-left font-medium">Criado em</th>
                <th class="px-4 py-3 text-right font-medium">Ações</th>
            </tr>
        </thead>
        <tbody id="dns-body" class="divide-y divide-slate-800">
            <?php if (!$dnsList): ?>
                <tr><td colspan="6" class="px-4 py-10 text-center text-slate-500">Nenhum DNS cadastrado.</td></tr>
            <?php endif; ?>
            <?php foreach ($dnsList as $d): ?>
                <tr class="group cursor-move odd:bg-slate-900 even:bg-slate-900/40 hover:bg-slate-800/60" draggable="true" data-id="<?= (int) $d['id'] ?>">
                    <td class="px-4 py-3">
                        <input type="number" min="0" value="<?= (int) $d['prioridade'] ?>"
                               onchange="setPriority(<?= (int) $d['id'] ?>, this.value)"
                               class="w-16 rounded-md border border-slate-700 bg-slate-800 px-2 py-1 text-center text-sm text-white focus:border-brand-500 focus:outline-none">
                    </td>
                    <td class="px-4 py-3 font-medium text-white"><?= e($d['nome']) ?></td>
                    <td class="px-4 py-3">
                        <span class="text-slate-300"><?= e($d['url']) ?></span>
                        <span class="ml-2 text-xs font-medium ping-result" data-url="<?= e($d['url']) ?>"></span>
                    </td>
                    <td class="px-4 py-3">
                        <?php if ($d['ativo']): ?>
                            <span class="inline-flex items-center gap-1.5 rounded-full bg-emerald-500/15 px-2.5 py-0.5 text-xs font-medium text-emerald-400">
                                <span class="h-1.5 w-1.5 rounded-full bg-emerald-400"></span> Ativo
                            </span>
                        <?php else: ?>
                            <span class="inline-flex items-center gap-1.5 rounded-full bg-slate-600/30 px-2.5 py-0.5 text-xs font-medium text-slate-400">
                                <span class="h-1.5 w-1.5 rounded-full bg-slate-400"></span> Inativo
                            </span>
                        <?php endif; ?>
                    </td>
                    <td class="px-4 py-3 text-slate-400"><?= e(date('d/m/Y', strtotime($d['criado_em']))) ?></td>
                    <td class="px-4 py-3">
                        <div class="flex items-center justify-end gap-1.5">
                            <button onclick="pingTest(this)" data-url="<?= e($d['url']) ?>"
                                    class="rounded-md bg-sky-500/15 px-2.5 py-1.5 text-xs font-medium text-sky-400 hover:bg-sky-500/25" title="Testar">Testar</button>
                            <a href="edit.php?id=<?= (int) $d['id'] ?>"
                               class="rounded-md bg-slate-700/50 px-2.5 py-1.5 text-xs font-medium text-slate-300 hover:bg-slate-700">Editar</a>
                            <form method="post" class="inline">
                                <?= csrf_field() ?>
                                <input type="hidden" name="action" value="toggle">
                                <input type="hidden" name="id" value="<?= (int) $d['id'] ?>">
                                <button type="submit" class="rounded-md bg-amber-500/15 px-2.5 py-1.5 text-xs font-medium text-amber-400 hover:bg-amber-500/25">
                                    <?= $d['ativo'] ? 'Desativar' : 'Ativar' ?>
                                </button>
                            </form>
                            <form method="post" class="inline" onsubmit="return confirm('Remover este DNS?');">
                                <?= csrf_field() ?>
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="id" value="<?= (int) $d['id'] ?>">
                                <button type="submit" class="rounded-md bg-rose-500/15 px-2.5 py-1.5 text-xs font-medium text-rose-400 hover:bg-rose-500/25">Deletar</button>
                            </form>
                        </div>
                    </td>
                </tr>
            <?php endforeach; ?>
        </tbody>
    </table>
</div>

<!-- Modal Adicionar -->
<div id="modal" class="fixed inset-0 z-40 hidden items-center justify-center bg-black/60 p-4 backdrop-blur-sm">
    <div class="w-full max-w-md rounded-2xl border border-slate-800 bg-slate-900 p-6 shadow-2xl">
        <div class="mb-4 flex items-center justify-between">
            <h3 class="text-lg font-semibold text-white">Adicionar DNS</h3>
            <button onclick="closeModal()" class="text-slate-400 hover:text-white">&times;</button>
        </div>
        <form method="post" action="add.php" class="space-y-4">
            <?= csrf_field() ?>
            <div>
                <label class="mb-1.5 block text-sm font-medium text-slate-300">Nome</label>
                <input type="text" name="nome" required class="w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white focus:border-brand-500 focus:outline-none" placeholder="Servidor Principal">
            </div>
            <div>
                <label class="mb-1.5 block text-sm font-medium text-slate-300">URL</label>
                <input type="url" name="url" required class="w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white focus:border-brand-500 focus:outline-none" placeholder="http://servidor.com">
            </div>
            <div class="flex items-center gap-4">
                <div class="flex-1">
                    <label class="mb-1.5 block text-sm font-medium text-slate-300">Prioridade</label>
                    <input type="number" name="prioridade" min="0" value="<?= count($dnsList) + 1 ?>" class="w-full rounded-lg border border-slate-700 bg-slate-800 px-4 py-2.5 text-sm text-white focus:border-brand-500 focus:outline-none">
                </div>
                <label class="mt-6 flex items-center gap-2 text-sm text-slate-300">
                    <input type="checkbox" name="ativo" checked class="h-4 w-4 rounded border-slate-600 bg-slate-800 text-brand-600 focus:ring-brand-500"> Ativo
                </label>
            </div>
            <div class="flex justify-end gap-2 pt-2">
                <button type="button" onclick="closeModal()" class="rounded-lg px-4 py-2.5 text-sm font-medium text-slate-300 hover:bg-slate-800">Cancelar</button>
                <button type="submit" class="rounded-lg bg-brand-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-brand-700">Salvar</button>
            </div>
        </form>
    </div>
</div>

<script>
    const CSRF = <?= json_encode(csrf_token()) ?>;

    function openModal()  { const m = document.getElementById('modal'); m.classList.remove('hidden'); m.classList.add('flex'); }
    function closeModal() { const m = document.getElementById('modal'); m.classList.add('hidden'); m.classList.remove('flex'); }

    // --- Teste de ping (AJAX) ---
    async function pingTest(btn) {
        const url = btn.dataset.url;
        const out = document.querySelector(`.ping-result[data-url="${CSS.escape(url)}"]`);
        const old = btn.textContent;
        btn.textContent = '...'; btn.disabled = true;
        if (out) { out.textContent = 'testando...'; out.className = 'ml-2 text-xs font-medium ping-result text-slate-400'; }
        try {
            const res = await fetch('ping_test.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: new URLSearchParams({ url, csrf_token: CSRF })
            });
            const data = await res.json();
            if (out) {
                if (data.ok) { out.textContent = `● ${data.ms} ms`; out.className = 'ml-2 text-xs font-medium ping-result text-emerald-400'; }
                else { out.textContent = '● offline'; out.className = 'ml-2 text-xs font-medium ping-result text-rose-400'; }
            }
            toast(data.ok ? 'success' : 'error', data.ok ? `Respondeu em ${data.ms} ms` : 'Servidor não respondeu');
        } catch (e) {
            if (out) { out.textContent = '● erro'; out.className = 'ml-2 text-xs font-medium ping-result text-rose-400'; }
            toast('error', 'Falha no teste');
        } finally { btn.textContent = old; btn.disabled = false; }
    }

    // --- Prioridade numérica (AJAX) ---
    async function setPriority(id, value) {
        await fetch('index.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: new URLSearchParams({ action: 'set_priority', id, prioridade: value, csrf_token: CSRF })
        });
        toast('success', 'Prioridade atualizada');
    }

    // --- Drag and drop ---
    (function () {
        const body = document.getElementById('dns-body');
        let dragged = null;
        body.querySelectorAll('tr[draggable]').forEach(row => {
            row.addEventListener('dragstart', () => { dragged = row; row.classList.add('opacity-40'); });
            row.addEventListener('dragend',   () => { row.classList.remove('opacity-40'); saveOrder(); });
            row.addEventListener('dragover', (ev) => {
                ev.preventDefault();
                const after = ev.clientY > row.getBoundingClientRect().top + row.offsetHeight / 2;
                if (dragged && dragged !== row) row.parentNode.insertBefore(dragged, after ? row.nextSibling : row);
            });
        });
        async function saveOrder() {
            const ids = [...body.querySelectorAll('tr[data-id]')].map(r => r.dataset.id);
            // Reflete a nova ordem nos inputs numéricos
            body.querySelectorAll('tr[data-id]').forEach((r, i) => {
                const inp = r.querySelector('input[type=number]'); if (inp) inp.value = i + 1;
            });
            await fetch('index.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: new URLSearchParams({ action: 'reorder', order: JSON.stringify(ids), csrf_token: CSRF })
            });
            toast('success', 'Ordem salva');
        }
    })();
</script>

<?php layout_footer($base); ?>
