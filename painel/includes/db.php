<?php
/**
 * Conexão PDO com o banco de dados.
 * Uso: $pdo = db();
 */
require_once __DIR__ . '/../config.php';

function db(): PDO
{
    static $pdo = null;

    if ($pdo instanceof PDO) {
        return $pdo;
    }

    $dsn = sprintf(
        'mysql:host=%s;dbname=%s;charset=%s',
        DB_HOST,
        DB_NAME,
        DB_CHARSET
    );

    $options = [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
    ];

    try {
        $pdo = new PDO($dsn, DB_USER, DB_PASS, $options);
    } catch (PDOException $e) {
        if (APP_DEBUG) {
            die('Erro de conexão com o banco: ' . htmlspecialchars($e->getMessage()));
        }
        http_response_code(500);
        die('Erro de conexão com o banco de dados.');
    }

    return $pdo;
}
