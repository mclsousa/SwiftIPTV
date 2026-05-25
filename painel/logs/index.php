<?php
require_once __DIR__ . '/../includes/functions.php';
require_login('../');

$base = '../';
$pdo  = db();

// ----------------------------------------------------------------------------
// Filtros
// ----------------------------------------------------------------------------
$fUser   = trim($_GET['usuario'] ?? '');
$fData   = trim($_GET['data'] ?? '');
$fResult = trim($_GET['resultado'] ?? '');

$where  = [];
$params = [];
if ($fUser !== '')   { $where[] = 'username LIKE ?';       $params[] = '%' . $fUser . '%'; }
if ($fData !== '')   { $where[] = 'DATE(criado_em) = ?';   $params[] = $fData; }
if ($fResult === 'success' || $fResult === 'fail') { $where[] = 'resultado = ?'; $params[] = $fResult; }
$whereSql = $where ? 'WHERE ' . implode(' AND ', $where) : '';

// ----------------------------------------------------------------------------
// Exportar CSV (respeita os filtros)
// ----------------------------------------------------------------------------
if (isset($_GET['export']) && $_GET['export'] === 'csv') {
    $stmt = $pdo->prepare("SELECT id, username, ip, user_agent, resultado, mensagem, criado_em FROM logs_acesso $whereSql ORDER BY id DESC");
    $stmt->execute($params);

    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="logs_acesso_' . date('Ymd_His') . '.csv"');
    $out = fopen('php://output', 'w');
    fprintf($out, "\xEF\xBB\xBF"); // BOM UTF-8 para Excel
    fputcsv($out, ['ID', 'Usuário', 'IP', 'User-Agent', 'Resultado', 'Mensagem', 'Data']);
    while ($row = $stmt->fetch()) {
        fputcsv($out, [$row['id'], $row['username'], $row['ip'], $row['user_agent'], $row['resultado'], $row['mensagem'], $row['criado_em']]);
    }
    fclose($out);
    exit;
}

// ----------------------------------------------------------------------------
// Paginação
// ----------------------------------------------------------------------------
$perPage = 20;
$page    = max(1, (int) ($_GET['page'] ?? 1));
$offset  = ($page - 1) * $perPage;

$countStmt = $pdo->prepare("SELECT COUNT(*) FROM logs_acesso $whereSql");
$countStmt->execute($params);
$total      = (int) $countStmt->fetchColumn();
$totalPages = max(1, (int) ceil($total / $perPage));

$listStmt = $pdo->prepare("SELECT * FROM logs_acesso $whereSql ORDER BY id DESC LIMIT $perPage OFFSET $offset");
$listStmt->execute($params);
$logs = $listStmt->fetchAll();

// Querystring base para links (preserva filtros)
$qs = http_build_query(array_filter(['usuario' => $fUser, 'data' => $fData, 'resultado' => $fResult]));

layout_header('Logs de Acesso', 'logs', $base);
?>

<!-- Filtros -->
<form method="get" class="mb-5 flex flex-wrap items-end gap-3 rounded-xl border border-slate-800 bg-slate-900 p-4">
    <div>
        <label class="mb-1 block text-xs font-medium text-slate-400">Usuário</label>
        <input type="text" name="usuario" value="<?= e($fUser) ?>" placeholder="buscar..." class="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white focus:border-brand-500 focus:outline-none">
    </div>
    <div>
        <label class="mb-1 block text-xs font-medium text-slate-400">Data</label>
        <input type="date" name="data" value="<?= e($fData) ?>" class="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white focus:border-brand-500 focus:outline-none [color-scheme:dark]">
    </div>
    <div>
        <label class="mb-1 block text-xs font-medium text-slate-400">Resultado</label>
        <select name="resultado" class="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white focus:border-brand-500 focus:outline-none">
            <option value="">Todos</option>
            <option value="success" <?= $fResult === 'success' ? 'selected' : '' ?>>Sucesso</option>
            <option value="fail"    <?= $fResult === 'fail' ? 'selected' : '' ?>>Falha</option>
        </select>
    </div>
    <button type="submit" class="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-700">Filtrar</button>
    <a href="index.php" class="rounded-lg px-4 py-2 text-sm font-medium text-slate-400 hover:bg-slate-800">Limpar</a>
    <a href="?export=csv<?= $qs ? '&' . e($qs) : '' ?>" class="ml-auto inline-flex items-center gap-2 rounded-lg bg-emerald-600 px-4 py-2 text-sm font-semibold text-white hover:bg-emerald-700">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
        Exportar CSV
    </a>
</form>

<div class="overflow-hidden rounded-xl border border-slate-800 bg-slate-900">
    <table class="w-full text-sm">
        <thead class="bg-slate-800/50 text-xs uppercase tracking-wide text-slate-400">
            <tr>
                <th class="px-4 py-3 text-left font-medium">Usuário</th>
                <th class="px-4 py-3 text-left font-medium">IP</th>
                <th class="px-4 py-3 text-left font-medium">User-Agent</th>
                <th class="px-4 py-3 text-left font-medium">Resultado</th>
                <th class="px-4 py-3 text-left font-medium">Mensagem</th>
                <th class="px-4 py-3 text-left font-medium">Data</th>
            </tr>
        </thead>
        <tbody class="divide-y divide-slate-800">
            <?php if (!$logs): ?>
                <tr><td colspan="6" class="px-4 py-10 text-center text-slate-500">Nenhum log encontrado.</td></tr>
            <?php endif; ?>
            <?php foreach ($logs as $l): ?>
                <tr class="odd:bg-slate-900 even:bg-slate-900/40 hover:bg-slate-800/60">
                    <td class="px-4 py-3 font-medium text-white"><?= e($l['username']) ?></td>
                    <td class="px-4 py-3 text-slate-400"><?= e($l['ip']) ?></td>
                    <td class="px-4 py-3 max-w-[200px] truncate text-slate-500" title="<?= e($l['user_agent']) ?>"><?= e($l['user_agent']) ?></td>
                    <td class="px-4 py-3">
                        <?php if ($l['resultado'] === 'success'): ?>
                            <span class="rounded-full bg-emerald-500/15 px-2.5 py-0.5 text-xs font-medium text-emerald-400">sucesso</span>
                        <?php else: ?>
                            <span class="rounded-full bg-rose-500/15 px-2.5 py-0.5 text-xs font-medium text-rose-400">falha</span>
                        <?php endif; ?>
                    </td>
                    <td class="px-4 py-3 text-slate-400"><?= e($l['mensagem']) ?></td>
                    <td class="px-4 py-3 whitespace-nowrap text-slate-400"><?= e(date('d/m/Y H:i:s', strtotime($l['criado_em']))) ?></td>
                </tr>
            <?php endforeach; ?>
        </tbody>
    </table>
</div>

<!-- Paginação -->
<div class="mt-4 flex items-center justify-between text-sm text-slate-400">
    <span><?= $total ?> registro(s) — página <?= $page ?> de <?= $totalPages ?></span>
    <div class="flex gap-1">
        <?php $prevDisabled = $page <= 1; $nextDisabled = $page >= $totalPages; ?>
        <a href="<?= $prevDisabled ? '#' : '?page=' . ($page - 1) . ($qs ? '&' . e($qs) : '') ?>"
           class="rounded-lg border border-slate-700 px-3 py-1.5 <?= $prevDisabled ? 'pointer-events-none opacity-40' : 'hover:bg-slate-800' ?>">Anterior</a>
        <a href="<?= $nextDisabled ? '#' : '?page=' . ($page + 1) . ($qs ? '&' . e($qs) : '') ?>"
           class="rounded-lg border border-slate-700 px-3 py-1.5 <?= $nextDisabled ? 'pointer-events-none opacity-40' : 'hover:bg-slate-800' ?>">Próxima</a>
    </div>
</div>

<?php layout_footer($base); ?>
