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

# Usuário SFTP da agência, compartilhando o grupo do Apache
RUN useradd \
    --create-home \
    --home-dir /site \
    --shell /usr/sbin/nologin \
    --gid www-data \
    agencia-seo

# Estrutura do chroot.
# /sftp/agencia PRECISA permanecer root:root e não gravável pelo usuário SFTP.
RUN mkdir -p \
    /sftp/agencia/site \
    /run/sshd \
    /var/log/supervisor \
    && chown root:root /sftp /sftp/agencia \
    && chmod 755 /sftp /sftp/agencia

COPY apache/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY ssh/sshd_config /etc/ssh/sshd_config
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod 755 /usr/local/bin/docker-entrypoint.sh

EXPOSE 80 22

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
