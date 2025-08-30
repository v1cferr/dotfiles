# Como usar o Stow direito

## A Lógica do `stow` 💡

O "pulo do gato" do `stow` é o seguinte: **A estrutura de pastas *dentro* do seu "pacote" (ex: `~/dotfiles/hypr`) deve imitar a estrutura de pastas a partir do seu diretório HOME (`~`).**

O `stow` não adivinha onde você quer colocar os arquivos. Ele olha para a estrutura que você criou e a replica com links simbólicos.

## Corrigindo seu Fluxo de Trabalho

Vamos pegar seus exemplos e fazer do jeito certo. Assumindo que você está dentro do seu diretório `~/dotfiles`.

### Para o `hypr` (um diretório em `~/.config/`)

O caminho final que você quer é um link em `~/.config/hypr`.
Portanto, o `stow` precisa encontrar os arquivos em `~/dotfiles/hypr/.config/hypr`.

O seu erro foi mover `~/.config/hypr` para `~/dotfiles/hypr/.config/`, criando `~/dotfiles/hypr/.config/hypr`. Você precisa criar a estrutura *parente* e mover o diretório final para dentro dela.

**O jeito certo:**

```bash
# 1. Esteja no seu diretório de dotfiles
cd ~/dotfiles

# 2. Crie a estrutura de diretórios que imita o caminho a partir da HOME
# O diretório 'hypr' está dentro de '.config', então criamos '.config' aqui.
mkdir -p hypr/.config

# 3. Mova sua configuração ATUAL para o lugar CERTO dentro do pacote
# Agora sim, mova ~/.config/hypr para dentro de hypr/.config/
mv ~/.config/hypr hypr/.config/

# 4. Rode o stow!
stow hypr
```

Agora, o `stow` vai olhar dentro de `~/dotfiles/hypr`, ver a pasta `.config/hypr`, e criar um link simbólico de `~/dotfiles/hypr/.config/hypr` para `~/.config/hypr`. Perfeito.

### Para o `zsh` (um arquivo na `~/`)

O caminho final que você quer é um link em `~/.zshrc`.
Portanto, o `stow` precisa encontrar o arquivo em `~/dotfiles/zsh/.zshrc`.

Seu erro foi mover `~/.zshrc` para `./zsh/`, criando `~/dotfiles/zsh/.zshrc`. `stow zsh` então tentaria criar um link para uma pasta inteira chamada `zsh` na sua HOME.

**O jeito certo:**

```bash
# 1. Esteja no seu diretório de dotfiles
cd ~/dotfiles

# 2. Crie o pacote para o zsh (se ainda não existir)
mkdir zsh

# 3. Mova seu arquivo .zshrc para dentro do pacote
mv ~/.zshrc zsh/

# 4. Rode o stow!
stow zsh
```

Agora, o `stow` vai olhar dentro de `~/dotfiles/zsh`, ver o arquivo `.zshrc`, e criar um link simbólico de `~/dotfiles/zsh/.zshrc` para `~/.zshrc`.

## Regra de Ouro 🧠

Pense assim: o `stow` pega o conteúdo da pasta do pacote (ex: `~/dotfiles/hypr`) e o "transporta" para a sua pasta HOME (`~`).

- Se dentro de `~/dotfiles/hypr` existe um arquivo em `.config/hypr/hyprland.conf`, ele criará um link em `~/.config/hypr/hyprland.conf`.
- Se dentro de `~/dotfiles/zsh` existe um arquivo `.zshrc`, ele criará um link em `~/.zshrc`.

Sua confusão é a curva de aprendizado normal da ferramenta. Depois que essa lógica "clica", `stow` vira algo automático e super poderoso para gerenciar seus dotfiles.
