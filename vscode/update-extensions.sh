#!/bin/bash
# Atualiza a lista de extensões do VS Code

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
code --list-extensions > "$SCRIPT_DIR/extensions.txt"
echo "✅ Lista de extensões atualizada ($(wc -l < "$SCRIPT_DIR/extensions.txt") extensões)"
