#!/bin/bash
set -euo pipefail

SITE_DIR="/sftp/agencia/site"
CHROOT_DIR="/sftp/agencia"
SFTP_USER="agencia-seo"
AUTHORIZED_KEYS_FILE="/etc/ssh/authorized_keys/${SFTP_USER}"

echo "[seo-php] Inicializando container..."

# O chroot precisa permanecer sob controle do root.
mkdir -p "$CHROOT_DIR" "$SITE_DIR" /run/sshd
chown root:root /sftp "$CHROOT_DIR"
chmod 755 /sftp "$CHROOT_DIR"

# O volume Railway deve ser montado exatamente em /sftp/agencia/site.
# A agência escreve; Apache (www-data) lê, mas não ganha escrita por padrão.
# -h impede que um link simbólico malicioso altere o dono do alvo fora do volume.
chown -hR "$SFTP_USER":www-data "$SITE_DIR"
find "$SITE_DIR" -type d -exec chmod 2755 {} \;
find "$SITE_DIR" -type f -exec chmod 0644 {} \;

# Página inicial apenas se o volume estiver vazio.
if [ -z "$(find "$SITE_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
  cat > "$SITE_DIR/index.php" <<'PHP'
<?php
header('Content-Type: text/html; charset=UTF-8');
echo '<h1>SEO PHP OK</h1><p>Ambiente PHP 8.3 ativo. Conteúdo gerenciado via SFTP.</p>';
PHP
  chown "$SFTP_USER":www-data "$SITE_DIR/index.php"
  chmod 0644 "$SITE_DIR/index.php"
fi

# Autenticação por senha opcional.
if [ -n "${AGENCIA_SEO_PASSWORD:-}" ]; then
  echo "${SFTP_USER}:${AGENCIA_SEO_PASSWORD}" | chpasswd
  echo "[seo-php] Autenticação SFTP por senha habilitada."
else
  # Um hash impossível desabilita senha sem marcar a conta como bloqueada.
  # Contas bloqueadas pelo passwd -l também são recusadas para chave pública.
  usermod --password '*' "$SFTP_USER"
  echo "[seo-php] AGENCIA_SEO_PASSWORD não definida; senha SFTP desabilitada."
fi

# A chave fica fora do DocumentRoot e é recriada a partir da variável a cada deploy.
# AuthorizedKeysFile é lido pelo sshd antes da entrada no chroot.
if [ -n "${AGENCIA_SEO_AUTHORIZED_KEY:-}" ]; then
  install -d -o root -g root -m 0755 "$(dirname "$AUTHORIZED_KEYS_FILE")"
  printf '%s\n' "$AGENCIA_SEO_AUTHORIZED_KEY" > "$AUTHORIZED_KEYS_FILE"
  chown root:root "$AUTHORIZED_KEYS_FILE"
  chmod 0644 "$AUTHORIZED_KEYS_FILE"
  echo "[seo-php] Chave pública SFTP configurada."
else
  rm -f "$AUTHORIZED_KEYS_FILE"
fi

if [ -z "${AGENCIA_SEO_PASSWORD:-}" ] && [ -z "${AGENCIA_SEO_AUTHORIZED_KEY:-}" ]; then
  echo "[seo-php] ERRO: configure AGENCIA_SEO_PASSWORD e/ou AGENCIA_SEO_AUTHORIZED_KEY." >&2
  exit 1
fi

# Gera host keys do SSH se necessário.
ssh-keygen -A

# Garante um único MPM compatível com mod_php também no runtime.
a2dismod -f mpm_event mpm_worker >/dev/null 2>&1 || true
a2enmod mpm_prefork >/dev/null

# Valida configurações antes de iniciar.
apache2ctl configtest
/usr/sbin/sshd -t

# Apache/PHP não precisam herdar as credenciais usadas na inicialização.
unset AGENCIA_SEO_PASSWORD AGENCIA_SEO_AUTHORIZED_KEY

echo "[seo-php] Apache DocumentRoot: $SITE_DIR"
echo "[seo-php] SFTP interno: porta 22"
echo "[seo-php] Iniciando Apache + SSH via Supervisor..."

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
