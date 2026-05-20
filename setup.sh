#!/bin/bash
set -e

echo "🚀 Iniciando setup do Jorge (opencode config)"

# 1. Criar diretório global do opencode se não existir
mkdir -p ~/.config/opencode

# 2. Remover arquivos/links existentes (se houver)
rm -f ~/.config/opencode/AGENTS.md
rm -f ~/.config/opencode/opencode.jsonc
rm -rf ~/.config/opencode/agents

# 3. Criar symlinks apontando para o repositório
ln -s ~/configOpenCode/AGENTS.md ~/.config/opencode/AGENTS.md
ln -s ~/configOpenCode/opencode.jsonc ~/.config/opencode/opencode.jsonc
ln -s ~/configOpenCode/agents ~/.config/opencode/agents

# 4. Marcar diretórios como seguros para Git (WSL)
git config --global --add safe.directory '*'

echo ""
echo "✅ Setup concluído! Jorge está pronto para uso."
echo "📁 Configs em: ~/configOpenCode/"
echo "🔗 Symlinks criados em: ~/.config/opencode/"
