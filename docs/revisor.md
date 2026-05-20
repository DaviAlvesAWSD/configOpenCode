# Revisor — Subagente de Revisão de Código

## O que é

O **Revisor** é um subagente do OpenCode especializado em revisão técnica de código. Ele analisa alterações do Git (`git diff`) e fornece feedback detalhado como um arquiteto sênior faria — explicando problemas, fundamentos e soluções, sem nunca modificar arquivos.

## Como usar

Em qualquer conversa com o Jorge, basta mencionar `@revisor`:

```
@revisor
```

Jorge coletará as alterações atuais (`git diff`) e invocará o revisor automaticamente.

## Fluxo de revisão

1. **Jorge prepara o diff** — executa `git diff` e identifica os arquivos alterados por extensão (.ts, .tsx, .js, .scss, etc.)
2. **Revisor pergunta o escopo** — o revisor pergunta:

   > "Mestre, deseja revisar apenas as mudanças atuais (diff) ou o arquivo inteiro para refatoração futura?"

   - **Apenas mudanças atuais** — análise focada somente nas linhas alteradas
   - **Arquivo inteiro** — leitura completa do arquivo para sugerir refatorações

3. **Revisão detalhada** — cada problema é apresentado com:

   | Seção | Descrição |
   |-------|-----------|
   | ❌ O que está errado | Trecho problemático com arquivo e linha |
   | 📘 Por que está errado | Fundamento técnico violado (padrão, segurança, performance) |
   | ✅ Como corrigir | Código sugerido (apenas explicativo) |
   | 💡 O que mudou e por que | Explicação didática da correção |

4. **Classificação por severidade**

   - 🔴 **Alto** — erro funcional, segurança, quebra de compilação
   - 🟡 **Médio** — violação de boas práticas, débito técnico
   - 🟢 **Baixo** — sugestão cosmética ou melhoria opcional

5. **Revisor nunca altera arquivos** — se você quiser aplicar as correções, peça ao Jorge explicitamente.

## Escopo da análise

O revisor cobre:

- **Arquitetura** — acoplamento, coesão, separação de responsabilidades
- **Clean Code / SOLID** — legibilidade, nomes, tamanho de métodos, princípios
- **Segurança** — injeção, vazamento de dados, permissões
- **Performance** — queries N+1, loops desnecessários, renderização
- **React / TypeScript** — hooks, props, tipagem, estado, memoização
- **Testabilidade** — código testável, mocks
- **Boas práticas** — exceções, null safety, async/await, error boundary

## Regras importantes

- O revisor **NUNCA modifica arquivos** — é exclusivamente leitura e análise
- O revisor responde **sempre em português brasileiro**
- A revisão é **técnica, construtiva e didática** — o objetivo é que o Mestre aprenda com o processo
- O revisor **não faz análise profunda de commits antigos** — apenas `git log -3` para contexto básico

## Exemplo de saída

```
## Resumo das alterações
3 arquivos alterados (src/services/apis/UserAPI.ts, src/utils/dateUtils.ts, src/styles/_reset.scss)
Escopo: Apenas mudanças atuais

## Problemas encontrados

### 🔴 src/services/apis/UserAPI.ts:25

❌ **O que está errado**
```typescript
const response = await api.get('/users');
```

📘 **Por que está errado**
O método `get` não possui tipagem de retorno, o que faz com que `response` seja `any`. Isso desativa o TypeScript para toda a cadeia de uso desse dado.

✅ **Como corrigir**
```typescript
const response = await api.get<User[]>('/users');
```

💡 **O que mudou e por que**
Adicionamos o tipo genérico `User[]` ao `get`. Agora o TypeScript sabe exatamente qual é o formato do retorno, permitindo autocomplete e detectando erros de propriedade em tempo de compilação.

## Pontos positivos
- Uso correto de async/await
- Separação de responsabilidades na camada de serviço
```
