# Grupo Maximiano — SEO PHP Infra

Infraestrutura do serviço `seo-php` no Railway.

## Objetivo

Este repositório versiona **somente a infraestrutura** do container:

- PHP 8.3
- Apache
- OpenSSH / SFTP
- Supervisor
- configuração do Apache
- configuração do SSH

O conteúdo PHP mantido pela agência **não fica neste repositório**.

Os arquivos da agência ficam em um **Railway Volume** montado em:

```text
/sftp/agencia/site
```

O Apache usa esse mesmo diretório como `DocumentRoot`.

## Arquitetura

```text
GitHub
└── infraestrutura
    ├── Dockerfile
    ├── Apache
    ├── SSH/SFTP
    └── Supervisor
          │
          ▼
      Railway deploy

Agência
   │ SFTP
   ▼
Railway TCP Proxy
   │
   ▼
/sftp/agencia/site   ← Railway Volume
   │
   ▼
Apache + PHP 8.3
```

## Estrutura do repositório

```text
.
├── Dockerfile
├── docker-entrypoint.sh
├── supervisord.conf
├── apache/
│   └── 000-default.conf
├── ssh/
│   └── sshd_config
├── .dockerignore
├── .gitignore
└── README.md
```

## Configuração do Railway

### 1. Source

Conecte este repositório GitHub ao serviço `seo-php`.

Branch recomendada:

```text
main
```

O Railway deve detectar automaticamente o `Dockerfile`.

### 2. Volume

Monte o volume persistente `seo-php-data` exatamente em:

```text
/sftp/agencia/site
```

**Não monte o volume em `/sftp/agencia`.**

O diretório `/sftp/agencia` é o root do chroot SFTP e precisa permanecer:

```text
root:root
755
```

A subpasta `/site` é a área gravável pela agência.

### 3. Variáveis

Escolha ao menos um método de autenticação.

Senha:

```text
AGENCIA_SEO_PASSWORD=<senha-forte>
```

ou chave pública SSH:

```text
AGENCIA_SEO_AUTHORIZED_KEY=ssh-ed25519 AAAA...
```

Pode usar ambos.

Nunca coloque senha no Dockerfile ou no GitHub.

### 4. HTTP

Gere um domínio Railway para o serviço.

O Apache escuta internamente na porta:

```text
80
```

Teste:

```text
https://<dominio-railway>/
```

Se o volume estiver vazio, o entrypoint cria automaticamente uma página `index.php` de teste.

### 5. SFTP

Crie um TCP Proxy no Railway apontando para:

```text
porta interna: 22
```

O Railway fornecerá um host e uma porta externa.

Dados para a agência:

```text
Protocol: SFTP
Host: <host TCP Proxy Railway>
Port: <porta externa gerada>
Username: agencia-seo
Password: <AGENCIA_SEO_PASSWORD>
Remote directory: /site
```

No cliente SFTP, `ForceCommand internal-sftp -d /site` normalmente já abre diretamente na pasta correta.

## Teste ponta a ponta

Via SFTP, criar:

```text
teste.php
```

com:

```php
<?php
echo "SEO PHP OK";
```

Depois acessar:

```text
https://<dominio-railway>/teste.php
```

Esperado:

```text
SEO PHP OK
```

Faça então um redeploy do serviço.

O arquivo `teste.php` deve continuar existindo porque está no volume persistente.

## Deploy

Alterações neste repositório alteram apenas a infraestrutura:

```text
push/merge na main
→ Railway build
→ deploy do container
```

Alterações da agência via SFTP:

```text
SFTP
→ volume
→ Apache lê imediatamente
```

Não há deploy do Railway para alterações de conteúdo.

## Segurança

O usuário `agencia-seo`:

- não possui shell interativo;
- fica chrootado em `/sftp/agencia`;
- entra diretamente em `/site`;
- não tem TCP forwarding;
- não tem agent forwarding;
- não tem X11;
- não acessa outros serviços Railway;
- não acessa Postgres, MariaDB, WordPress, frontend ou backend.

## Observação importante

O diretório de chroot:

```text
/sftp/agencia
```

não pode ser gravável pelo usuário SFTP.

Por isso o volume deve ser montado na subpasta:

```text
/sftp/agencia/site
```

e não diretamente no diretório do chroot.

## Roteamento futuro

Mais adiante:

```text
grupomaximiano.com.br/servicos/*
→ seo-php
```

O domínio Railway deverá então ser tratado apenas como origin e não deve ser indexado.
