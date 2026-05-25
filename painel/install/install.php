<?php
/**
 * Instalador / seeder do SwiftIPTV Panel.
 *
 * Garante que o operador padrão (admin / admin123) e o cliente de exemplo
 * (teste / teste123) tenham hashes bcrypt VÁLIDOS para a instalação de PHP
 * em uso — útil quando os hashes inseridos via schema.sql não funcionam.
 *
 * Pré-requisito: as tabelas já devem existir (importe schema.sql antes).
 *
 * SEGURANÇA: apague este arquivo após o uso em produção.
 */
require_once __DIR__ . '/../includes/db.php';

$pdo  = db();
$msgs = [];

try {
    // ---- Operador admin / admin123 (upsert) ----
    $hashAdmin = password_hash('admin123', PASSWORD_BCRYPT);
    $stmt = $pdo->prepare(
        'INSERT INTO operadores (username, password_hash) VALUES (?, ?)
         ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash)'
    );
    $stmt->execute(['admin', $hashAdmin]);
    $msgs[] = 'Operador <strong>admin</strong> criado/atualizado (senha: <strong>admin123</strong>).';

    // ---- Cliente de exemplo teste / teste123 (upsert) ----
    $hashCli = password_hash('teste123', PASSWORD_BCRYPT);
    $stmt = $pdo->prepare(
        'INSERT INTO clientes (username, password_hash, ativo, expira_em) VALUES (?, ?, 1, ?)
         ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash)'
    );
    $stmt->execute(['teste', $hashCli, '2026-12-31']);
    $msgs[] = 'Cliente de exemplo <strong>teste</strong> criado/atualizado (senha: <strong>teste123</strong>).';

    // ---- DNS de exemplo (apenas se a tabela estiver vazia) ----
    $count = (int) $pdo->query('SELECT COUNT(*) FROM server_dns')->fetchColumn();
    if ($count === 0) {
        $pdo->exec(
            "INSERT INTO server_dns (nome, url, ativo, prioridade) VALUES
             ('Servidor Principal', 'http://servidor1.com', 1, 1),
             ('Servidor Backup',    'http://servidor2.com', 1, 2),
             ('Servidor CDN',       'http://servidor3.com', 1, 3)"
        );
        $msgs[] = '3 DNS de exemplo inseridos.';
    } else {
        $msgs[] = "DNS já existentes ($count) — nenhuma inserção feita.";
    }

    $ok = true;
} catch (Throwable $e) {
    $ok = false;
    $msgs[] = 'Erro: ' . htmlspecialchars($e->getMessage());
    $msgs[] = 'Verifique se você importou <code>schema.sql</code> e se o <code>config.php</code> está correto.';
}
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <title>Instalador — SwiftIPTV Panel</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="min-h-screen bg-slate-950 text-slate-200 flex items-center justify-center p-4 font-sans">
    <div class="w-full max-w-lg rounded-2xl border border-slate-800 bg-slate-900 p-8">
        <h1 class="mb-4 text-xl font-bold text-white">Instalador do SwiftIPTV Panel</h1>
        <div class="rounded-lg border <?= $ok ? 'border-emerald-500/40 bg-emerald-500/10' : 'border-rose-500/40 bg-rose-500/10' ?> p-4">
            <ul class="space-y-1.5 text-sm">
                <?php foreach ($msgs as $m): ?>
                    <li>• <?= $m ?></li>
                <?php endforeach; ?>
            </ul>
        </div>
        <?php if ($ok): ?>
            <p class="mt-4 text-sm text-amber-300">⚠ Por segurança, <strong>apague este arquivo</strong> (install/install.php) após concluir.</p>
            <a href="../login.php" class="mt-5 inline-block rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-indigo-700">Ir para o login →</a>
        <?php endif; ?>
    </div>
</body>
</html>
