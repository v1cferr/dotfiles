# Zen Browser - Tokyo Night

Tema customizado do Zen Browser baseado na paleta oficial do Tokyo Night, usando como fonte o arquivo oficial do tema:

- <https://github.com/tokyo-night/tokyo-night-vscode-theme/blob/master/themes/tokyo-night-color-theme.json>

## Arquivos versionados

- `userChrome.css`: overrides visuais da interface do Zen
- `user.js`: preferências persistentes para habilitar `userChrome.css` e live editing

## Como aplicar

1. Aplique o pacote `bin` se ainda não estiver linkado (traz `zen-sync` e `tokyo-night` ao PATH):

```bash
stow bin
```

2. Sincronize o tema com o perfil padrão do Zen:

```bash
tokyo-night zen
```

Ou diretamente:

```bash
zen-sync
```

O script detecta automaticamente o perfil padrão em `~/.zen/profiles.ini`, cria a pasta `chrome/` se necessário e liga estes arquivos versionados ao perfil ativo.

## Paleta usada

- Background principal: `#1a1b26`
- Superfície: `#16161e`, `#202330`, `#1e202e`
- Texto: `#a9b1d6`, `#c0caf5`
- Destaques: `#7aa2f7`, `#bb9af7`, `#73daca`
- Feedback: `#e0af68`, `#f7768e`, `#9ece6a`

## Observações

- O arquivo `zen-themes.css` do Zen pode ser gerado automaticamente por mods. Por isso, a customização versionada aqui usa `userChrome.css`, que é o ponto estável suportado pelo próprio Zen.
- Se você trocar de perfil e o diretório padrão mudar, basta rodar `zen-sync` de novo.