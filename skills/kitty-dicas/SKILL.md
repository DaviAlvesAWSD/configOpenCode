---
name: kitty-dicas
description: Use quando o Mestre perguntar sobre o terminal kitty, trocar tema, transparência ou fundo da janela. Cobre o comando de temas e a chave background_opacity.
---

# Dicas e truques CLI — kitty

- Trocar tema do kitty: comando é `kitty +kitten themes` (com "kitten" no SINGULAR,
  não "kittens"). Sem argumento abre seletor interativo; com nome do tema aplica direto
  (ex.: `kitty +kitten themes 'Catppuccin-Mocha'`).
- O kitty grava o tema escolhido em `current-theme.conf` e o `kitty.conf` o referencia com
  `include current-theme.conf`.
- O kitty NÃO suporta a chave `background_blur` (não a reconhece); manter apenas
  `background_opacity` para transparência.
