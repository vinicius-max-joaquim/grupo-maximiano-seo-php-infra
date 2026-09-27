#!/bin/bash
set -euo pipefail

SITE_DIR="/sftp/agencia/site"
CHROOT_DIR="/sftp/agencia"
SFTP_USER="agencia-seo"

echo "[seo-php] Inicializando container..."

# O chroot precisa permanecer sob controle do root.
mkdir -p "$CHROOT_DIR" "$SITE_DIR" /run/sshd
chown root:root /sftp "$CHROOT_DIR"
chmod 755 /sftp "$CHROOT_DIR"

# O volume Railway deve ser montado exatamente em /sftp/agencia/site.
# A agência escreve; Apache (www-data) lê.
chown -R "$SFTP_USER":www-data "$SITE_DIR"
find "$SITE_DIR" -type d -exec chmod 2775 {} \; || true
find "$SITE_DIR" -type f -exec chmod 0664 {} \; || true

# Página inicial apenas se o volume estiver vazio.
if [ -z "$(find "$SITE_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
  cat > "$SITE_DIR/index.php" <<'PHP'
<?php
header('Content-Type: text/html; charset=UTF-8');
echo '<h1>SEO PHP OK</h1><p>Ambiente PHP 8.3 ativo. Conteúdo gerenciado via SFTP.</p>';
PHP
  chown "$SFTP_USER":www-data "$SITE_DIR/index.php"
  chmod 0664 "$SITE_DIR/index.php"
fi

# Autenticação por senha opcional.
if [ -n "${AGENCIA_SEO_PASSWORD:-}" ]; then
  echo "${SFTP_USER}:${AGENCIA_SEO_PASSWORD}" | chpasswd
  echo "[seo-php] Autenticação SFTP por senha habilitada."
else
  # Bloqueia senha se nenhuma senha foi configurada.
  passwd -l "$SFTP_USER" >/dev/null 2>&1 || true
  echo "[seo-php] AGENCIA_SEO_PASSWORD não definida; senha SFTP desabilitada."
fi

# Autenticação por chave SSH opcional.
if [ -n "${AGENCIA_SEO_AUTHORIZED_KEY:-}" ]; then
  mkdir -p "$SITE_DIR/.ssh"
  printf '%s\n' "$AGENCIA_SEO_AUTHORIZED_KEY" > "$SITE_DIR/.ssh/authorized_keys"
  chown -R "$SFTP_USER":www-data "$SITE_DIR/.ssh"
  chmod 700 "$SITE_DIR/.ssh"
  chmod 600 "$SITE_DIR/.ssh/authorized_keys"
  echo "[seo-php] Chave pública SFTP configurada."
fi

# Gera host keys do SSH se necessário.
ssh-keygen -A

# Valida configurações antes de iniciar.
apache2ctl configtest
/usr/sbin/sshd -t

echo "[seo-php] Apache DocumentRoot: $SITE_DIR"
echo "[seo-php] SFTP interno: porta 22"
echo "[seo-php] Iniciando Apache + SSH via Supervisor..."

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
