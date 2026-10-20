---
description: Gera o release técnico (revisor/MR) e o Release Notes do cliente (Jira) no padrão MV.
---

Use a skill `release-notes`.

Contexto informado: $ARGUMENTS

Procedimento:

1. Identifique a natureza pelo prefixo do ticket (PROD/SUP = Qualidade;
   CIMP/MERC/DL/PRODSM/PORTAL DO CLIENTE = Implementação). Se ambíguo, pergunte.
2. Levante o que faltar em uma única lista curta: ticket(s), localização completa com
   MÓDULO/ID, perfil de acesso, ajuste de banco e, se o Mestre informar, o cliente.
3. Se houver alterações no repositório, leia o `git diff` antes de escrever.
   Em repositórios com CRLF, use `git diff --ignore-cr-at-eol`.
4. Entregue os dois blocos, nesta ordem e com estes títulos:

=== RELEASE TÉCNICO (revisor/MR) ===

<conteúdo técnico>

=== RELEASE NOTES — CLIENTE (Jira) ===

<conteúdo no padrão MV, pronto para colar>

5. No bloco do cliente, siga estritamente o template da natureza, em texto corrido,
   com as regras de escrita, localização e TICKET RELACIONADO da skill.
6. Não invente caminho de menu, MÓDULO/ID ou número de ticket.
