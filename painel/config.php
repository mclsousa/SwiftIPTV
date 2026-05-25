<?php
/**
 * SwiftIPTV Panel - Configuração central
 * --------------------------------------
 * Edite as constantes abaixo de acordo com o seu ambiente.
 * Após instalar, troque SECRET_KEY por uma string aleatória longa.
 */

// ----------------------------------------------------------------------------
// Banco de dados (MySQL 8 / MariaDB)
// ----------------------------------------------------------------------------
define('DB_HOST', 'localhost');   // Host do MySQL
define('DB_NAME', 'swiftiptv');   // Nome do banco (criado via schema.sql)
define('DB_USER', 'root');        // Usuário do banco
define('DB_PASS', '');            // Senha do banco
define('DB_CHARSET', 'utf8mb4');

// ----------------------------------------------------------------------------
// Modo de autenticação dos CLIENTES (não confundir com o login do operador)
//   'local'  -> valida pela tabela `clientes` do próprio painel
//   'xtream' -> valida consultando um painel Xtream Codes externo
// ----------------------------------------------------------------------------
define('AUTH_MODE', 'local');

// URL base do painel Xtream (só usado se AUTH_MODE = 'xtream')
// Ex.: http://meupainel.com:8080  (sem barra no final)
define('XTREAM_URL', 'http://seupainel.com');

// ----------------------------------------------------------------------------
// Segurança
// ----------------------------------------------------------------------------
define('SESSION_NAME', 'swiftiptv_session');
// IMPORTANTE: troque por uma string aleatória longa e secreta.
define('SECRET_KEY', 'troque_por_string_aleatoria_longa');

// Origem permitida para a API (CORS). Use '*' para liberar geral
// ou informe a origem exata do app, ex.: 'https://app.seudominio.com'
define('API_ALLOWED_ORIGIN', '*');

// ----------------------------------------------------------------------------
// Rate limiting da API (/api/auth.php)
//   Máximo RATE_LIMIT_MAX tentativas por IP a cada RATE_LIMIT_WINDOW segundos
// ----------------------------------------------------------------------------
define('RATE_LIMIT_MAX', 10);
define('RATE_LIMIT_WINDOW', 60);

// ----------------------------------------------------------------------------
// Geral
// ----------------------------------------------------------------------------
define('APP_NAME', 'SwiftIPTV Panel');
date_default_timezone_set('America/Sao_Paulo');

// Exibe erros em desenvolvimento. Defina como false em produção.
define('APP_DEBUG', true);
if (APP_DEBUG) {
    error_reporting(E_ALL);
    ini_set('display_errors', '1');
} else {
    error_reporting(0);
    ini_set('display_errors', '0');
}
