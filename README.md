# configOpenCode

Configurações globais do Jorge (agente opencode) para uso em qualquer projeto.

## O que contém

| Arquivo | Função |
|---------|--------|
| `AGENTS.md` | Regras de comportamento: terceira pessoa, sem commit em projetos de aplicação |
| `opencode.jsonc` | Trava técnica: bloqueia `git commit/push/merge` em projetos normais |
| `opencode.json` | Override que libera git apenas neste repositório |
| `agents/revisor.md` | Agente `@revisor` para revisão de código (Java, TypeScript, React) |
| `setup.sh` | Script de instalação automatizada |

## Setup em máquina nova

### Pré-requisitos
- opencode instalado
- Chave SSH configurada no GitHub

### Passo a passo

```bash
# 1. Clonar o repositório
git clone git@github.com:DaviAlvesAWSD/configOpenCode.git ~/configOpenCode

# 2. Executar o setup
bash ~/configOpenCode/setup.sh
```

O script de setup:
1. Cria `~/.config/opencode/` se não existir
2. Remove arquivos/link existentes
3. Cria symlinks de `~/.config/opencode/` para `~/configOpenCode/`
4. Marca diretórios como seguros para Git (necessário para WSL)

### O que o setup faz

```
~/configOpenCode/ (repositório git)
├── AGENTS.md
├── opencode.jsonc
├── opencode.json
├── agents/revisor.md
└── setup.sh
       ↓ symlinks
~/.config/opencode/
├── AGENTS.md     → ~/configOpenCode/AGENTS.md
├── opencode.jsonc → ~/configOpenCode/opencode.jsonc
└── agents/       → ~/configOpenCode/agents/
```

## Proteções do Jorge

| Local | Git commit/push/merge |
|-------|----------------------|
| Projetos de aplicação (back-end, front-end) | Bloqueado (técnica e instrucionalmente) |
| `~/configOpenCode` | Liberado |

## Como usar o @revisor

Em qualquer projeto, digite no chat:

```
@revisor
```

O agente:
1. Lista arquivos alterados com `git diff --name-only`
2. Identifica extensões automaticamente (.java, .ts, .tsx, .js)
3. Revisa cada grupo com o diff apropriado
4. Responde em português brasileiro

## Verificação manual

Para confirmar que os symlinks estão funcionando:

```bash
ls -la ~/.config/opencode/
# Deve mostrar:
# AGENTS.md -> /home/seuuser/configOpenCode/AGENTS.md
# opencode.jsonc -> /home/seuuser/configOpenCode/opencode.jsonc
# agents -> /home/seuuser/configOpenCode/agents
```
