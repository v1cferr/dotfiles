# VS Code Configuration

Configurações do Visual Studio Code gerenciadas pelo GNU Stow.

## Uso

```bash
# Aplicar configurações
cd ~/dotfiles
stow vscode

# Instalar extensões
cat vscode/extensions.txt | xargs -L1 code --install-extension

# Atualizar lista de extensões
cd vscode && ./update-extensions.sh
```

## Estrutura

- `settings.json` - Configurações principais
- `keybindings.json` - Atalhos personalizados  
- `snippets/` - Snippets customizados
- `extensions.txt` - Lista de extensões instaladas
