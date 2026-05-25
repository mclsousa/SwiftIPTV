# SwiftIPTV Panel

Painel web em PHP para um operador de IPTV gerenciar **clientes**, **servidores DNS** e **logs de acesso**, com um endpoint de API consumido por um app externo (ex.: app Windows).

---

## 🧱 Stack

- PHP 8.2+ (extensões: `pdo_mysql`, `curl`, `json`)
- MySQL 8 ou MariaDB
- Tailwind CSS via CDN + JavaScript vanilla
- Tema dark, responsivo, fonte Inter

---

## 📁 Estrutura

```
painel/
├── config.php                 # constantes de configuração
├── index.php                  # dashboard
├── login.php / logout.php
├── dns/                       # CRUD de servidores DNS + ping_test (AJAX)
├── clientes/                  # CRUD de clientes (modo local) ou aviso (modo xtream)
├── logs/                      # logs de acesso + filtros + export CSV
├── api/auth.php               # endpoint usado pelo app externo
├── includes/                  # db.php, auth.php, functions.php
├── assets/                    # style.css, app.js
└── install/                   # schema.sql, install.php
```

---

## 🚀 Instalação passo a passo

### 1. Copie os arquivos
Coloque a pasta `painel/` na raiz pública do seu servidor web (Apache, Nginx + PHP-FPM, ou XAMPP/Laragon no Windows).
Exemplo XAMPP: `C:\xampp\htdocs\painel\`.

### 2. Crie o banco e importe o schema
```bash
# cria o banco e todas as tabelas + dados iniciais
mysql -u root -p < painel/install/schema.sql
```
Ou, pelo phpMyAdmin: crie o banco `swiftiptv` e importe `install/schema.sql`.

### 3. Configure o `config.php`
Edite `painel/config.php`:

| Constante        | Descrição                                                        |
|------------------|------------------------------------------------------------------|
| `DB_HOST/NAME/USER/PASS` | Credenciais do MySQL                                     |
| `AUTH_MODE`      | `'local'` (banco do painel) ou `'xtream'` (painel Xtream externo) |
| `XTREAM_URL`     | URL do painel Xtream (só no modo `xtream`)                       |
| `SECRET_KEY`     | **Troque** por uma string aleatória longa                        |
| `API_ALLOWED_ORIGIN` | Origem CORS permitida para a API (`*` ou domínio do app)     |
| `RATE_LIMIT_MAX` / `RATE_LIMIT_WINDOW` | Limite de tentativas por IP (padrão 10/60s) |

### 4. Garanta o operador (recomendado)
Como o ambiente onde o schema foi gerado pode diferir da sua versão do PHP, abra **uma vez** no navegador:
```
http://SEU_HOST/painel/install/install.php
```
Ele recria com hash bcrypt válido:
- Operador: **admin / admin123**
- Cliente de exemplo: **teste / teste123**

> 🔒 **Apague `install/install.php` depois de usar.**

### 5. Acesse o painel
```
http://SEU_HOST/painel/login.php
```
Credenciais padrão: **admin / admin123** (troque a senha em produção).

---

## ⚙️ Modos de autenticação dos clientes

### Modo `local` (padrão)
Clientes ficam na tabela `clientes`. A tela **Clientes** permite listar, adicionar, editar, ativar/desativar e definir expiração (datepicker). Indicadores: **verde** = ativo, **vermelho** = expirado, **cinza** = inativo.

### Modo `xtream`
Defina `AUTH_MODE = 'xtream'` e `XTREAM_URL`. O login é validado contra
`{XTREAM_URL}/player_api.php?username=...&password=...` (checando `user_info.auth == 1`).
A tela **Clientes** exibe apenas um aviso — o gerenciamento é feito no painel Xtream.

---

## 🔌 API — `POST /painel/api/auth.php`

Chamada pelo app externo. **Somente POST com `Content-Type: application/json`.**

**Requisição**
```json
{ "username": "cliente", "password": "senha" }
```

**Resposta — sucesso**
```json
{
  "ok": true,
  "token": "<sha256>",
  "server_dns": ["http://servidor1.com", "http://servidor2.com"],
  "username_iptv": "cliente",
  "password_iptv": "senha",
  "expires_at": "2026-12-31"
}
```

**Resposta — falha**
```json
{ "ok": false, "message": "Usuário ou senha incorretos" }
```

Comportamento:
- `server_dns` retorna todos os DNS com `ativo = 1`, ordenados por `prioridade` ASC.
- Todo acesso (sucesso ou falha) é registrado em `logs_acesso`.
- **Rate limiting**: máx. `RATE_LIMIT_MAX` requisições por IP em `RATE_LIMIT_WINDOW` segundos (HTTP 429 ao exceder).
- Cabeçalhos: `Content-Type: application/json`, CORS restrito a `API_ALLOWED_ORIGIN`.

**Exemplo de teste (curl):**
```bash
curl -X POST http://SEU_HOST/painel/api/auth.php \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"teste\",\"password\":\"teste123\"}"
```

---

## 🗂️ Funcionalidades

- **Dashboard**: clientes ativos, DNS ativos, acessos hoje/7 dias, gráfico de barras (JS puro) dos últimos 7 dias e os 10 últimos acessos.
- **DNS**: tabela com status/prioridade, modal de adição, editar/ativar/desativar/deletar, **teste de latência via AJAX** (`ping_test.php`), reordenação por **drag-and-drop** e por campo numérico.
- **Logs**: filtros por usuário/data/resultado, paginação (20/página) e **exportar CSV**.

---

## 🔐 Segurança implementada

- Senhas com **bcrypt** (`password_hash`/`password_verify`).
- Sessão com nome customizado, cookie `HttpOnly`/`SameSite` e **regeneração de ID** no login.
- Proteção **CSRF** em todos os formulários e ações AJAX do painel.
- Consultas **PDO com prepared statements** (anti SQL injection).
- Escape de saída HTML (anti XSS).
- Rate limiting na API.

### Checklist para produção
1. Trocar `SECRET_KEY` e a senha do `admin`.
2. Definir `APP_DEBUG = false` no `config.php`.
3. Apagar `install/install.php`.
4. Servir sob **HTTPS** (o cookie de sessão vira `Secure` automaticamente).
5. Restringir `API_ALLOWED_ORIGIN` ao domínio do app.

---

## Credenciais padrão

| Tipo      | Usuário | Senha     |
|-----------|---------|-----------|
| Operador  | admin   | admin123  |
| Cliente (exemplo, modo local) | teste | teste123 |
