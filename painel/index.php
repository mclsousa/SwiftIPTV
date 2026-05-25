<?php
require_once __DIR__ . '/includes/functions.php';
require_login();

$pdo = db();

// --- Métricas ---
if (AUTH_MODE === 'local') {
    $clientesAtivos = (int) $pdo->query("SELECT COUNT(*) FROM clientes WHERE ativo = 1 AND (expira_em IS NULL OR expira_em >= CURDATE())")->fetchColumn();
} else {
    $clientesAtivos = null; // gerenciado pelo Xtream
}
$dnsAtivos    = (int) $pdo->query("SELECT COUNT(*) FROM server_dns WHERE ativo = 1")->fetchColumn();
$acessosHoje  = (int) $pdo->query("SELECT COUNT(*) FROM logs_acesso WHERE DATE(criado_em) = CURDATE()")->fetchColumn();
$acessosSemana= (int) $pdo->query("SELECT COUNT(*) FROM logs_acesso WHERE criado_em >= (NOW() - INTERVAL 7 DAY)")->fetchColumn();

// --- Dados do gráfico (últimos 7 dias) ---
$chart = [];
for ($i = 6; $i >= 0; $i--) {
    $dia = date('Y-m-d', strtotime("-$i day"));
    $chart[$dia] = 0;
}
$stmt = $pdo->query("SELECT DATE(criado_em) AS dia, COUNT(*) AS total
                     FROM logs_acesso
                     WHERE criado_em >= (CURDATE() - INTERVAL 6 DAY)
                     GROUP BY DATE(criado_em)");
foreach ($stmt as $row) {
    $chart[$row['dia']] = (int) $row['total'];
}

// --- Últimos 10 acessos ---
$ultimos = $pdo->query("SELECT username, ip, resultado, criado_em FROM logs_acesso ORDER BY id DESC LIMIT 10")->fetchAll();

layout_header('Dashboard', 'dashboard');

$cards = [
    ['label' => 'Clientes Ativos', 'value' => $clientesAtivos === null ? '—' : $clientesAtivos, 'icon' => 'users',  'color' => 'brand'],
    ['label' => 'DNS Ativos',      'value' => $dnsAtivos,     'icon' => 'server', 'color' => 'emerald'],
    ['label' => 'Acessos Hoje',    'value' => $acessosHoje,   'icon' => 'clock',  'color' => 'sky'],
    ['label' => 'Acessos 7 dias',  'value' => $acessosSemana, 'icon' => 'list',   'color' => 'amber'],
];
$colorMap = [
    'brand'   => 'bg-brand-500/15 text-brand-400',
    'emerald' => 'bg-emerald-500/15 text-emerald-400',
    'sky'     => 'bg-sky-500/15 text-sky-400',
    'amber'   => 'bg-amber-500/15 text-amber-400',
];
?>

<!-- Cards -->
<div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
    <?php foreach ($cards as $c): ?>
        <div class="rounded-xl border border-slate-800 bg-slate-900 p-5">
            <div class="flex items-center justify-between">
                <span class="text-sm font-medium text-slate-400"><?= e($c['label']) ?></span>
                <span class="flex h-9 w-9 items-center justify-center rounded-lg <?= $colorMap[$c['color']] ?>"><?= icon($c['icon']) ?></span>
            </div>
            <p class="mt-3 text-3xl font-bold text-white"><?= e($c['value']) ?></p>
        </div>
    <?php endforeach; ?>
</div>

<div class="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-2">
    <!-- Gráfico -->
    <div class="rounded-xl border border-slate-800 bg-slate-900 p-5">
        <h2 class="mb-4 text-sm font-semibold text-white">Acessos nos últimos 7 dias</h2>
        <div class="flex h-48 items-end justify-between gap-2" id="chart"></div>
    </div>

    <!-- Últimos acessos -->
    <div class="rounded-xl border border-slate-800 bg-slate-900 p-5">
        <h2 class="mb-4 text-sm font-semibold text-white">Últimos 10 acessos</h2>
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead>
                    <tr class="text-left text-xs uppercase tracking-wide text-slate-500">
                        <th class="pb-2 font-medium">Usuário</th>
                        <th class="pb-2 font-medium">IP</th>
                        <th class="pb-2 font-medium">Data</th>
                        <th class="pb-2 font-medium">Resultado</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-slate-800">
                    <?php if (!$ultimos): ?>
                        <tr><td colspan="4" class="py-6 text-center text-slate-500">Nenhum acesso registrado.</td></tr>
                    <?php endif; ?>
                    <?php foreach ($ultimos as $r): ?>
                        <tr class="text-slate-300">
                            <td class="py-2.5 font-medium text-white"><?= e($r['username']) ?></td>
                            <td class="py-2.5 text-slate-400"><?= e($r['ip']) ?></td>
                            <td class="py-2.5 text-slate-400"><?= e(date('d/m H:i', strtotime($r['criado_em']))) ?></td>
                            <td class="py-2.5">
                                <?php if ($r['resultado'] === 'success'): ?>
                                    <span class="rounded-full bg-emerald-500/15 px-2.5 py-0.5 text-xs font-medium text-emerald-400">sucesso</span>
                                <?php else: ?>
                                    <span class="rounded-full bg-rose-500/15 px-2.5 py-0.5 text-xs font-medium text-rose-400">falha</span>
                                <?php endif; ?>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<script>
    const chartData = <?= json_encode(array_map(function ($d, $v) {
        return ['label' => date('d/m', strtotime($d)), 'value' => $v];
    }, array_keys($chart), array_values($chart))) ?>;

    (function renderChart() {
        const el = document.getElementById('chart');
        const max = Math.max(1, ...chartData.map(d => d.value));
        el.innerHTML = chartData.map(d => {
            const h = Math.round((d.value / max) * 100);
            return `<div class="flex flex-1 flex-col items-center gap-2">
                <div class="flex w-full flex-1 items-end">
                    <div class="w-full rounded-t-md bg-gradient-to-t from-brand-700 to-brand-500 transition-all hover:from-brand-600 hover:to-brand-400"
                         style="height:${Math.max(h,2)}%" title="${d.value} acesso(s)"></div>
                </div>
                <span class="text-[10px] font-medium text-slate-500">${d.label}</span>
                <span class="-mt-1 text-xs font-semibold text-slate-300">${d.value}</span>
            </div>`;
        }).join('');
    })();
</script>

<?php layout_footer(); ?>
