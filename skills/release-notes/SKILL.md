---
name: release-notes
description: Use quando o Mestre pedir para escrever, revisar ou padronizar Release Notes (PROD, SUP, CIMP, MERC, DL, PRODSM, PORTAL DO CLIENTE) no padrão MV, gerando o release técnico para o revisor do merge e o Release Notes do cliente para o Jira.
---

# Release Notes — padrão MV

Esta skill produz **dois artefatos** para cada demanda:

1. **Release técnico** — para o revisor do merge/MR. Pode usar linguagem técnica.
2. **Release Notes do cliente** — texto para o campo "Release Notes Comments" do Jira.
   Segue estritamente o padrão da empresa, pois passa por auditoria.

Nunca entregue apenas um dos dois, a menos que o Mestre peça explicitamente.

---

## 1. Natureza do ticket

Existem apenas duas naturezas. Detecte pelo prefixo do ticket:

| Prefixo | Natureza |
|---|---|
| `PROD`, `SUP` | Problema / Qualidade |
| `CIMP`, `MERC`, `DL`, `PRODSM` | Implementação |
| `PORTAL DO CLIENTE` | Implementação (ticket de serviço do cliente) |

Se o prefixo não permitir decidir, **pergunte** ao Mestre. Não invente.

---

## 2. Informações necessárias

Antes de escrever, confirme o que faltar. Faça **uma única lista curta** de perguntas:

- Ticket(s) relacionado(s)
- Localização completa: caminho de menu + tela + `(M_XXX)`, quando existir
- Perfil de acesso, quando for relevante
- Houve ajuste de banco de dados? (sim/não e o que foi ajustado)
- `Cliente:` — opcional, usar apenas quando o Mestre informar
- Para o release técnico: branch/MR e como testar (Jorge pode inferir do diff)

Nunca invente caminho de menu, MÓDULO/ID ou número de ticket. Se não souber, pergunte.

Para caminhos já mapeados, consulte `produtos.md` (mesma pasta desta skill).
Para exemplos aprovados, consulte `exemplos.md`.

---

## 3. Formato da entrega

Sempre nesta ordem, com os títulos exatos:

```
=== RELEASE TÉCNICO (revisor/MR) ===

<conteúdo técnico>

=== RELEASE NOTES — CLIENTE (Jira) ===

<conteúdo no padrão MV, pronto para colar>
```

Se houver mais de um release notes para a mesma task, coloque um abaixo do outro,
separados por quebra de linha (regra da empresa).

---

## 4. Release técnico (revisor/MR)

Estrutura:

```
RELEASE TÉCNICO — <TICKET>
Natureza: Qualidade | Implementação
Branch / MR: <informar ou "a confirmar">

CAUSA / CONTEXTO:
<o que estava errado ou o que foi implementado, em nível técnico>

ALTERAÇÕES:
- <arquivo/componente>: <o que mudou e por quê>

COMPORTAMENTO:
- Antes: <...>
- Depois: <...>

IMPACTO / RISCO:
<outros fluxos afetados, migração, configuração, rollback>

COMO TESTAR:
1. <passo>
2. <passo>

OBSERVAÇÕES:
- Banco/migração: <...>
- Configuração/parâmetro: <...>
```

Regras do release técnico:

- Pode citar classe, método, tabela, coluna, endpoint, SQL.
- Se houver alterações no repositório, leia o `git diff` antes de escrever.
  Em repositórios com CRLF, use `git diff --ignore-cr-at-eol` para não poluir a leitura.
- Seja fiel ao que foi alterado; não descreva mudanças que não existem no diff.
- "Como testar" deve ser executável por outra pessoa.

---

## 5. Release Notes do cliente — Problema / Qualidade

Template:

```
LOCALIZAÇÃO: <caminho completo>

OCORRÊNCIA: <texto corrido>

ALTERAÇÃO: <texto corrido>

TICKET RELACIONADO: <ticket>
```

### Ocorrência

- Verbos sempre no **passado** (o problema ocorria e foi solucionado).
- Linguagem informativa, focada no entendimento do cliente.
- Descreva o erro como o usuário o via; não descreva a causa técnica.
- Cite campos, colunas e botões com o nome exibido em tela, não o nome do código.
- Se citar uma tela que não está na localização, informe o caminho completo dela.
- Texto corrido.

### Alteração

- Verbos no **presente** (o problema está solucionado).
- Não mencione que o ajuste foi feito para um cliente específico.
- Descreva as alterações na **mesma ordem** dos problemas relatados na ocorrência.
- Prefira linguagem de cliente. Nomenclatura técnica (parâmetro, código, objeto de banco)
  só quando ajudar a explicar o ajuste, conforme permite a documentação da empresa.
- Nunca cite stack trace, nome de classe ou detalhe de implementação.
- Texto corrido.
- Ajuste de banco: descrever como "ajustes na base de dados do cliente".

---

## 6. Release Notes do cliente — Implementação

Template:

```
LOCALIZAÇÃO: <caminho completo>

DESCRIÇÃO: <texto corrido>

TICKET RELACIONADO: <ticket>
```

### Descrição

Explique, em texto corrido:

- o que foi implementado;
- para que serve;
- onde usar essas informações;
- o impacto da implementação no sistema;
- o que precisa ser configurado para a tela/botão/aba/campo aparecer, se for o caso.

Para implementações de processo com várias telas, descreva cada tela e as dependências
entre elas. Se citar tela fora da localização, informe o caminho completo com o MÓDULO/ID.

---

## 7. Regras de LOCALIZAÇÃO

- Informe o caminho completo: menu + tela + `(MÓDULO/ID)`.
- Separe os itens do caminho com barras (`/`).
- MÓDULO/ID em **maiúsculas** e entre parênteses. Exemplo:
  `Atendimento / Ambulatório / Configurações / Parâmetros (M_CONFIG_PARA)`.
- Não inclua o sistema no módulo: `(M_GLOSAS)` está certo; `(M_GLOSAS/FFAG)` está errado.
- A localização começa na seleção do produto.
- Se a tela é acessada por botão: localização da tela principal + nome do botão.
  Exemplo: `... / Gerenciamento de Exames (M_ADMIN_EXA_LAB) / Botão < Resultado >`.
- Se é acessada por ícone: localização da tela principal + hint entre aspas.
  Exemplo: `... / Ícone "Imprime Nota Fiscal" (M_NOTA_FISCAL)`.
- Ícone sem hint: descreva-o. Exemplo: `... / Ícone de lupa (M_CONSULTA_PACIENTE)`.
- Mais de uma localização: uma por linha.
- Sem localização específica: informe onde ocorreu a alteração.
- Impacto em várias telas/relatórios: localização genérica + um exemplo de tela.
- Processo específico de país/região: destaque com asterisco.
  Exemplo: `*Processo específico do Chile.`

---

## 8. Regras de escrita (auditoria)

- Use aspas duplas ao citar nomes de telas, campos, relatórios e abas.
- Use `< >` ao citar nomes de botões.
- Texto corrido no release do cliente. Sem bullets.
- Não use jargão técnico no release do cliente.
- `TICKET RELACIONADO` é obrigatório.
  - Um ticket: `TICKET RELACIONADO: ...`
  - Mais de um: `TICKETS RELACIONADOS: ... / ... / ...` (barras, nunca vírgulas)
  - Implementação: referencie o ticket de serviço (`CIMP`, `MERC`, `DL`, `PROD`, `PRODSM`).
  - Problema/Qualidade: referencie o `PROD` ou `SUP` de origem (ou o ticket interno).
  - Portal do Cliente: `PORTAL DO CLIENTE - 12345`.
- `Cliente:` é um campo extra do Mestre, opcional. A documentação da empresa não o prevê.
  Quando informado, coloque como primeira linha, antes de `LOCALIZAÇÃO:`.

---

## 9. Checklist antes de entregar

- [ ] Natureza correta (Qualidade ou Implementação)
- [ ] Os dois blocos entregues (técnico e cliente)
- [ ] `LOCALIZAÇÃO` com caminho completo e MÓDULO/ID, quando existir
- [ ] Ocorrência no passado / Alteração no presente
- [ ] Texto corrido, aspas duplas e `< >` conforme a regra
- [ ] `TICKET RELACIONADO` no singular ou plural correto
- [ ] Sem jargão técnico no release do cliente
- [ ] Nenhum caminho, MÓDULO ou ticket inventado
- [ ] Técnico compatível com o `git diff` (quando houver repositório)

---

## 10. Referências

- `exemplos.md` — exemplos oficiais e casos reais normalizados
- `produtos.md` — caminhos de menu e MÓDULO/ID por produto
