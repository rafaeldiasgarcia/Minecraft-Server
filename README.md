# Minecraft Server no GitHub Codespaces

Servidor de Minecraft Java automatizado com Docker Compose dentro do GitHub Codespaces, usando a imagem `itzg/minecraft-server`.

## Estrutura

```text
.
├── .devcontainer/
│   └── devcontainer.json
├── data/
│   └── mundo, configuracoes, plugins e arquivos do servidor
├── docker-compose.yml
└── README.md
```

O volume `./data:/data` guarda o mundo e as configuracoes do servidor. Tudo que o Minecraft gerar ali pode ser salvo no Git.

## Como rodar

Ao criar ou rebuildar o Codespace, o Dev Container usa o `docker-compose.yml` e sobe o servico `mc` automaticamente.

Se precisar subir manualmente:

```bash
docker compose up -d
```

Para ver o status:

```bash
docker compose ps
```

Para acompanhar os logs:

```bash
docker compose logs -f mc
```

O servidor terminou de iniciar quando aparecer algo parecido com:

```text
Done (...)! For help, type "help"
```

## Como entrar no servidor

1. Abra o painel `Ports` no VS Code/Codespaces.
2. Procure a porta `25565`, com o label `Minecraft Server`.
3. No VS Code Desktop, copie o `Local Address` da porta `25565`.
4. No Minecraft Java, va em `Multiplayer` > `Add Server`.
5. No campo `Server Address`, use o endereco local copiado.

Na maioria dos casos, usando o VS Code Desktop conectado ao Codespace, o endereco sera:

```text
localhost:25565
```

ou:

```text
127.0.0.1:25565
```

Importante: o endereco publico do Codespaces, como este:

```text
https://vigilant-fiesta-4jgx6j46wpj35jx7-25565.app.github.dev
```

funciona bem para apps HTTP/HTTPS, mas nao deve ser usado como IP direto no Minecraft. O Minecraft usa um protocolo TCP proprio e normalmente vai dar timeout nesse endereco publico do Codespaces.

Para outras pessoas entrarem pela internet, use um tunel TCP proprio para Minecraft, como playit.gg, ngrok TCP ou uma VPS. O Codespaces sozinho e melhor para jogar localmente pelo seu VS Code Desktop.

## Como salvar o progresso do mapa

Antes de fechar o Codespace, salve o mundo no Git:

```bash
git add data
git commit -m "Save Minecraft world progress"
git push
```

Para salvar tambem mudancas na infraestrutura:

```bash
git add docker-compose.yml .devcontainer/devcontainer.json scripts .gitignore data README.md
git commit -m "Configure automated Minecraft server"
git push
```

## Auto-save a cada 30 minutos

Este repositório tem um script em `scripts/minecraft-autosave.sh` que roda automaticamente quando o Codespace inicia.

Ele faz este ciclo a cada 30 minutos:

```text
save-all flush no servidor -> git add data -> git commit -> git push
```

O primeiro auto-save acontece 30 minutos depois que o Codespace sobe. Para forcar um save agora:

```bash
scripts/minecraft-autosave.sh once
```

Ver se o auto-save esta rodando:

```bash
scripts/minecraft-autosave.sh status
```

Iniciar manualmente:

```bash
scripts/minecraft-autosave.sh start
```

Parar:

```bash
scripts/minecraft-autosave.sh stop
```

Ver o log do auto-save:

```bash
tail -f .minecraft-autosave.log
```

O arquivo `data/.gitignore` evita salvar caches, logs, jars e bibliotecas geradas pelo servidor. O foco do Git fica no mundo e nas configuracoes importantes.

## Comandos uteis

Parar o servidor:

```bash
docker compose stop
```

Iniciar novamente:

```bash
docker compose up -d
```

Reiniciar:

```bash
docker compose restart mc
```

Abrir o console RCON:

```bash
docker exec -i minecraft-server-mc-1 rcon-cli
```

Ver portas publicadas pelo Codespaces:

```bash
gh codespace ports -c "$CODESPACE_NAME"
```

Marcar a porta `25565` como publica manualmente:

```bash
gh codespace ports visibility 25565:public -c "$CODESPACE_NAME"
```

Referencia: documentacao oficial do GitHub sobre port forwarding em Codespaces: https://docs.github.com/en/codespaces/developing-in-a-codespace/forwarding-ports-in-your-codespace
