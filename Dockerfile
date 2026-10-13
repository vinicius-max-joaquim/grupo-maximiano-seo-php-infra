FROM php:8.3-apache

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    supervisor \
    curl \
    unzip \
    libzip-dev \
    libonig-dev \
    && rm -rf /var/lib/apt/lists/*

RUN a2enmod rewrite headers expires

RUN docker-php-ext-install \
    mysqli \
    pdo \
    pdo_mysql \
    mbstring \
    zip

# Reduz a superfície disponível para código PHP enviado por SFTP.
# O site continua podendo usar o próprio volume e arquivos temporários.
RUN { \
      echo 'expose_php = Off'; \
      echo 'open_basedir = /sftp/agencia/site:/tmp'; \
      echo 'disable_functions = exec,passthru,shell_exec,system,proc_open,popen,pcntl_exec,link,symlink'; \
    } > /usr/local/etc/php/conf.d/zz-security.ini

# Usuário SFTP da agência, compartilhando o grupo do Apache.
# O home é /site dentro do chroot; ele não deve existir fora do chroot.
RUN useradd \
    --no-create-home \
    --home-dir /site \
    --shell /usr/sbin/nologin \
    --gid www-data \
    agencia-seo

# Estrutura do chroot.
# /sftp/agencia PRECISA permanecer root:root e não gravável pelo usuário SFTP.
RUN mkdir -p \
    /sftp/agencia/site \
    /etc/ssh/authorized_keys \
    /run/sshd \
    /var/log/supervisor \
    && chown root:root /sftp /sftp/agencia \
    && chmod 755 /sftp /sftp/agencia \
    && chown root:root /etc/ssh/authorized_keys \
    && chmod 755 /etc/ssh/authorized_keys

COPY apache/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY ssh/sshd_config /etc/ssh/sshd_config
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod 755 /usr/local/bin/docker-entrypoint.sh

EXPOSE 80 22

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
