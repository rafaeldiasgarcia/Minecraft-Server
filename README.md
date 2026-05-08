# Minecraft Server no GitHub Codespaces

Servidor de Minecraft Java automatizado com Docker Compose dentro do GitHub Codespaces, usando a imagem `itzg/minecraft-server`.

O perfil atual esta ajustado para Codespaces: `MEMORY=2G`, `view-distance=6`, `simulation-distance=4` e limite de 8 jogadores. Isso reduz quedas por falta de memoria/CPU quando varias pessoas exploram chunks ao mesmo tempo.

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

## Modo de autenticacao

O servidor esta configurado em `offline-mode`:

```text
online-mode=false
enforce-secure-profile=false
```

Isso permite conexoes sem validacao oficial da Microsoft/Mojang. E util para jogar com amigos que usam launchers sem sessao oficial, mas reduz a seguranca: qualquer pessoa pode tentar entrar usando qualquer nickname.

Recomendacao: se o endereco publico vazar, ative whitelist e libere apenas os nicks dos seus amigos.

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

### Voce no mesmo PC do VS Code

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

### Amigos em outros PCs

Para amigos entrarem pela internet, use o tunel TCP do `playit.gg`. O Codespaces sozinho nao entrega um IP publico TCP bom para Minecraft.

Este projeto ja tem um servico opcional `playit` no `docker-compose.yml`. Ele usa a imagem oficial `ghcr.io/playit-cloud/playit-agent`.

Passo a passo:

1. Crie uma conta em https://playit.gg.
2. No painel do playit, crie um agent do tipo Docker.
3. Copie o `secret key` do agent.
4. Crie o arquivo `.env` local:

```bash
cp .env.example .env
```

5. Edite o `.env` e coloque sua chave:

```text
PLAYIT_SECRET_KEY=sua-chave-do-playit-aqui
```

6. Suba o tunel:

```bash
scripts/playit-tunnel.sh start
```

7. Veja os logs:

```bash
scripts/playit-tunnel.sh logs
```

8. No painel do playit, crie um tunel para Minecraft Java apontando para:

```text
172.30.0.10:25565
```

O container do Minecraft recebe o IP fixo `172.30.0.10` na rede Docker interna. Assim o tunel continua apontando para o servidor certo mesmo quando os containers sao recriados.

O playit vai gerar um endereco publico, geralmente parecido com:

```text
alguma-coisa.playit.gg
```

ou:

```text
alguma-coisa.playit.gg:porta
```

Esse e o endereco que seus amigos colocam no Minecraft Java em `Multiplayer` > `Add Server` > `Server Address`.

Comandos do tunel:

```bash
scripts/playit-tunnel.sh status
scripts/playit-tunnel.sh start
scripts/playit-tunnel.sh stop
scripts/playit-tunnel.sh restart
scripts/playit-tunnel.sh watch-status
scripts/playit-tunnel.sh logs
```

Quando `PLAYIT_SECRET_KEY` esta configurado, o Codespace tambem inicia um watchdog do playit automaticamente. Ele recria o container do tunel se o container `mc` reiniciar ou se o proprio playit parar.

Para controlar esse watchdog manualmente:

```bash
scripts/playit-tunnel.sh watch-start
scripts/playit-tunnel.sh watch-stop
scripts/playit-tunnel.sh watch-status
```

Para deixar automatico em novos Codespaces, configure `PLAYIT_SECRET_KEY` como Codespaces secret no GitHub. Pelo terminal:

```bash
gh secret set PLAYIT_SECRET_KEY --user --app codespaces
```

Cole a chave do playit quando o GitHub CLI pedir. Depois reinicie/rebuild o Codespace.

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

Recuperar quando cair:

```bash
docker compose --profile public-tunnel up -d mc
scripts/playit-tunnel.sh restart
scripts/playit-tunnel.sh watch-start
```

Ver se esta tudo rodando:

```bash
docker compose --profile public-tunnel ps
```

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
