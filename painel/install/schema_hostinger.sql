-- =====================================================================
-- SwiftIPTV / DIGTV+ Panel - Schema para importação em Hostinger
-- (sem CREATE DATABASE / USE — o banco já existe e foi criado no hPanel)
--
-- Como usar:
--   phpMyAdmin -> selecione o banco (ex.: u116915193_digtv)
--   -> aba Importar -> escolha este arquivo -> Importar.
-- =====================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- Tabela: server_dns
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS server_dns;
CREATE TABLE server_dns (
    id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    nome          VARCHAR(150)  NOT NULL,
    url           VARCHAR(255)  NOT NULL,
    ativo         TINYINT(1)    NOT NULL DEFAULT 1,
    prioridade    INT           NOT NULL DEFAULT 0,
    criado_em     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_dns_ativo_prio (ativo, prioridade)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- Tabela: clientes (modo AUTH_MODE = 'local')
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS clientes;
CREATE TABLE clientes (
    id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    username      VARCHAR(191)  NOT NULL,
    password_hash VARCHAR(255)  NOT NULL,
    ativo         TINYINT(1)    NOT NULL DEFAULT 1,
    expira_em     DATE          NULL DEFAULT NULL,
    criado_em     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultimo_acesso DATETIME      NULL DEFAULT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_clientes_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- Tabela: logs_acesso
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS logs_acesso;
CREATE TABLE logs_acesso (
    id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    username   VARCHAR(191)  NOT NULL DEFAULT '',
    ip         VARCHAR(45)   NOT NULL DEFAULT '',
    user_agent VARCHAR(255)  NOT NULL DEFAULT '',
    resultado  ENUM('success','fail') NOT NULL DEFAULT 'fail',
    mensagem   VARCHAR(255)  NOT NULL DEFAULT '',
    criado_em  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_logs_ip_data (ip, criado_em),
    KEY idx_logs_data (criado_em),
    KEY idx_logs_user (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- Tabela: operadores (admins do painel)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS operadores;
CREATE TABLE operadores (
    id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    username      VARCHAR(191) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    criado_em     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_operadores_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- DADOS INICIAIS
-- =====================================================================

-- Operador padrão: admin / admin123
-- O hash abaixo pode falhar em algumas versões do PHP.
-- Se o login falhar, acesse install/install.php uma vez (ele regenera
-- o hash com a sua própria instalação do PHP) e DEPOIS APAGUE o arquivo.
INSERT INTO operadores (username, password_hash) VALUES
    ('admin', '$2y$10$e0NRcq3aQ7m4y9V5sQ1wEO1Qm6X1mY9b6mZ3T9kFqV2hQ0pY6oQqK');

-- 3 DNS de exemplo
INSERT INTO server_dns (nome, url, ativo, prioridade) VALUES
    ('Servidor Principal', 'http://servidor1.com', 1, 1),
    ('Servidor Backup',    'http://servidor2.com', 1, 2),
    ('Servidor CDN',       'http://servidor3.com', 1, 3);

-- Cliente de exemplo (modo local): teste / teste123
INSERT INTO clientes (username, password_hash, ativo, expira_em) VALUES
    ('teste', '$2y$10$Q9j5oP3mN1kL7vR2sT4uXeYbW8cZ6dA0fH2gI4jK6lM8nO0pQ2rSv', 1, '2026-12-31');
