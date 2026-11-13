# beautify-tmux

Config de tmux que pinta cada painel conforme o que o Claude Code dentro dele está fazendo.

🟡 trabalhando &nbsp; 🟢 terminou &nbsp; 🔴 esperando você

![Quatro sessões do Claude Code no tmux, cada borda com a cor do estado do agente](docs/demo.gif)

[English](README.md) · [Français](README.fr.md)

**O que é.** Um `tmux.conf` e um script de hook. Cada painel ganha um sinal na barra de título e a borda fica da mesma cor.

**Por que.** Eu deixo quatro, cinco agentes do Claude Code abertos no tmux pelo SSH. Um termina, outro para pedindo permissão, e eu só via minutos depois, quando batia o olho naquele painel.

**Pra que.** Olha a tela, vai no painel vermelho, responde. Os verdes estão livres pra próxima tarefa.

**Como.** O Claude Code roda hooks nos eventos dele. O `install.sh --claude` registra três. Cada um chama o `hooks/tmux-light.sh`, que grava uma opção do painel chamada `@light`, e a cor da borda no `tmux.conf` lê essa opção.

A config também põe uma barra de título com a pasta e o título da sessão, borda de linha dupla e Alt + setas pra trocar de painel.

## Instalar

Precisa do tmux 3.2 ou mais novo (`tmux -V`).

```sh
git clone https://github.com/felpk/beautify-tmux ~/.beautify-tmux
~/.beautify-tmux/install.sh
```

O instalador coloca uma linha `source-file` no seu `~/.tmux.conf` e guarda um backup do arquivo antigo. Rodar duas vezes não muda nada na segunda.

### Com o Claude Code

```sh
~/.beautify-tmux/install.sh --claude
```

Também registra três hooks no `~/.claude/settings.json` (precisa do `jq` e faz backup do arquivo antes):

| Evento do Claude Code | Sinal |
|---|---|
| Você manda um prompt | 🟡 |
| O Claude termina a vez dele | 🟢, ou 🔴 se a última linha da resposta for uma pergunta ou a resposta tiver um ❓ |
| O Claude pede permissão ou uma resposta | 🔴 |

Os hooks que você já tinha continuam lá.

### Com qualquer outra coisa

O sinal é só uma opção de painel chamada `@light`, então qualquer script pode mexer nela. O script do hook funciona sozinho:

```sh
~/.beautify-tmux/hooks/tmux-light.sh busy
make deploy && ~/.beautify-tmux/hooks/tmux-light.sh done || ~/.beautify-tmux/hooks/tmux-light.sh ask
```

Ou direto pelo tmux:

```sh
tmux set -p @light 🟢
tmux set -p -u @light   # apaga
```

Para ouvir também (1 bip 🟡, 2 🟢, 3 🔴), coloque `set -g @light-bell on` no seu `~/.tmux.conf`.

## Borda dividida (opcional)

No tmux normal, a borda entre dois painéis fica com uma cor só (a do painel ativo), então o sinal do vizinho some dali. A barra de título de cada painel sempre mostra a cor dele, mas se quiser as duas cores na borda:

```sh
~/.beautify-tmux/scripts/build-tmux.sh --install
```

Compila o tmux 3.4 com um patch pequeno (`patches/`) num container Docker descartável e instala em `/usr/local/bin/tmux`. A borda compartilhada fica meio a meio: o painel selecionado por último fica com a metade de cima (borda vertical) ou da direita (borda horizontal). Sessões que já estão abertas continuam com o tmux antigo; vale a partir do próximo servidor (`tmux kill-server` fecha tudo). Pra voltar: `rm /usr/local/bin/tmux`.

## Teclas

| Tecla | Ação |
|---|---|
| `Alt + ←` `→` `↑` `↓` | Vai pro painel naquela direção |
| `Prefixo` e depois `T` | Dá nome ao painel (vazio volta pro título do programa) |

O resto é o tmux de fábrica.

## Personalizar

Abra o `tmux.conf`. As cores são números de cor do tmux: `colour46` verde, `colour196` vermelho, `colour220` amarelo, `colour245` cinza, `colour239` a faixa atrás da borda. Depois de editar, rode `tmux source-file ~/.tmux.conf`.

Se preferir borda simples, troque `double` por `single` ou `heavy`.

## Desinstalar

```sh
~/.beautify-tmux/uninstall.sh
rm -rf ~/.beautify-tmux
```

Remove a linha `source-file` e os hooks do Claude Code que ele colocou. O resto da sua config fica como está.

## Como o GIF foi feito

O `scripts/demo.sh` roda este `tmux.conf` num servidor tmux descartável e chama o `hooks/tmux-light.sh` do mesmo jeito que o Claude Code chama, com o mesmo JSON na entrada. O texto dos agentes nos painéis é roteirizado. O Playwright e o ffmpeg transformam as capturas no GIF.

## Licença

MIT
