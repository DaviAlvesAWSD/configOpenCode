# Ensino — Validação do Código do Ministério da Saúde

**Caso real:** chamado de QA sobre o campo **“Código do ministério da saúde”** nas telas de
**Dose**, **Local da aplicação** e **Local de atendimento**.
**Sintoma:** o campo aceitava letras, mas o registro não salvava; às vezes sem mensagem, às
vezes com “Erro interno no servidor.”.
**Solução implementada:** diretiva `DigitsOnlyDirective` + validator
`MinisterioSaudeCodeValidator`.

Este documento existe para estudo posterior: explica o problema, o fluxo, as alternativas, os
conceitos e o código final.

---

## 1. O problema

Pré-condição do QA: estar logado, ter permissão de cadastro/edição e acessar:

- Cadastro > Dose > Novo ou Editar
- Cadastro > Local da aplicação > Novo ou Editar
- Cadastro > Local de atendimento > Novo ou Editar

Ao digitar caracteres não numéricos no campo “Código do ministério da saúde”:

- a tela aceitava a digitação;
- o botão salvar não concluía a operação;
- em alguns casos nenhuma mensagem aparecia, em outros aparecia uma mensagem genérica.

O comportamento era **diferente entre as telas**, o que é uma pista importante.

---

## 2. Onde o dado mora

| Tela | Endpoint | Tabela | Coluna | Auditoria |
|---|---|---|---|---|
| Dose | `POST/PUT /vacinas/api/tipo-dose` | `DBAVAC.TIPO_DOSE` | `CODIGO_MINISTERIO` | `DBAVACAUD.TIPO_DOSE_AUD` |
| Local da aplicação | `POST/PUT /vacinas/api/local-da-aplicacao` | `DBAVAC.LOCAL_APLICACAO` | `CODIGO_MINISTERIO` | `DBAVACAUD.LOCAL_APLICACAO_AUD` |
| Local de atendimento | `POST/PUT /vacinas/api/locais-atendimentos` | `DBAVAC.LOCAL_ATENDIMENTO` | `CODIGO_MINISTERIO` | `DBAVACAUD.LOCAL_ATENDIMENTO_AUD` |

### Banco × Java × tela

| Camada | Representação | Limite prático |
|---|---|---|
| Banco | `NUMBER(38,0)` | até 38 dígitos |
| Java | `Long` | ~19 dígitos (9,22 × 10¹⁸) |
| Tela | `maxlength="10"` | 10 dígitos |

Conclusões:

1. O campo é **numérico** no banco; letra não é um valor válido.
2. O limite de **10 dígitos é regra de tela/produto**, não do banco.
3. Como a tela limita a 10, o `Long` é suficiente. Se a regra passasse de 19 dígitos, a entidade
   precisaria de `BigInteger`/`BigDecimal`.
4. O changelog `SPCAVAC-2098` cria `LOCAL_APLICACAO.CODIGO_MINISTERIO` como `NUMBER(10)`, mas o
   banco real está `NUMBER(38,0)`. **Sempre confirme o DDL no banco**, não apenas no repositório.

---

## 3. O caminho da requisição

```
Tela Angular
  -> Service (MVCommonsGenericService)
  -> POST/PUT /vacinas/api/...
  -> Controller (@RestController)
  -> Business (@Service)
  -> Repository (JpaRepository)
  -> Hibernate/JPA
  -> Oracle (DBAVAC.TIPO_DOSE, LOCAL_APLICACAO, LOCAL_ATENDIMENTO)
```

Exemplo do Tipo Dose:

1. `salvar-tipo-dose-form.component.ts` monta o formulário e chama o service.
2. `TipoDoseService` envia `POST /vacinas/api/tipo-dose` (ou `PUT` na edição).
3. `TipoDoseController` recebe `TipoDoseRequest`.
4. `TipoDoseBusiness` converte o request em entidade.
5. `TipoDoseRepository` persiste.
6. A coluna `CODIGO_MINISTERIO` recebe o valor numérico.

O detalhe crítico: o `TipoDoseRequest.codigoMinisterio` é `Long`. Se o JSON chegar com
`"abc"`, o Jackson não consegue converter para `Long`.

---

## 4. Causa raiz

### 4.1 No front

Os três formulários tinham apenas `Validators.required` no campo. Nenhum deles impedia letra
na digitação/colagem.

### 4.2 No back

O campo é `Long`. Ao receber `"abc"`, o Spring lança `HttpMessageNotReadableException`.

Essa exceção cai no tratador genérico (`ValidationRulesExceptionAdvice`, `@ExceptionHandler(Exception.class)`),
que responde **HTTP 500** com a mensagem **“Erro interno no servidor.”**. Por isso a mensagem
genérica.

### 4.3 Por que as telas se comportavam diferente

| Tela | O que acontecia no salvar |
|---|---|
| Dose | `salvar()` checa `form.valid`; com letra, o formulário era inválido e o save era bloqueado |
| Local de atendimento | usa `ValidateUtil.validateAndShowMessage(this.form)`, que também bloqueia |
| Local da aplicação | `salvar()` **não** checa `form.valid`; enviava mesmo inválido e estourava o 500 |

### 4.4 A máscara existente não resolvia

O Local da aplicação usava `appVacinasMask="9999999999"`. Mas o `VacinasMaskDirective`:

- remove apenas caracteres **não alfanuméricos** (`[^a-zA-Z0-9]`);
- não valida se a posição `9` da máscara exige dígito;
- portanto, **aceita letras**.

Além disso, a máscara é um `ControlValueAccessor`; empilhar outra diretiva que também escreve no
controle poderia gerar conflito.

---

## 5. Alternativas avaliadas

| Opção | Vantagem | Problema |
|---|---|---|
| Só `Validators.pattern` | simples | não impede digitar; no Local da aplicação nem bloqueia o save |
| `type="number"` | nativo | aceita `e`, `+`, `-`, `.`; comportamento varia por navegador |
| Corrigir `appVacinasMask` global | resolve vários campos | alto raio de impacto (CNPJ, telefone, CEP etc.); exige regressão ampla |
| `filterInputNumber` do `mvcommons-ng` | já existe | exportado de forma interna (`ɵc`), sem uso no projeto; colagem não é totalmente tratada |
| **Diretiva + validator (escolhida)** | bloqueia digitação e valida | exige um arquivo novo e registro no módulo |

---

## 6. A solução implementada

### 6.1 Nomes

- **Diretiva:** `DigitsOnlyDirective` — seletor `input[appDigitsOnly]`
- **Validator:** `MinisterioSaudeCodeValidator` — erro `ministerioSaudeCodeInvalid`
- **Mensagem:** “Código inválido. Informe apenas números, com até 10 dígitos.”

### 6.2 Por que os dois?

- A **diretiva** melhora a experiência: a letra nem entra.
- O **validator** é a rede de segurança: cobre colagem, `setValue` programático, autofill e
  qualquer caminho que não passe pelo teclado.
- Só a diretiva deixaria o formulário “válido” para valores estranhos que chegassem por código.
- Só o validator deixaria o usuário digitar e só descobrir o erro depois.

---

## 7. Conceitos, um a um

### 7.1 Reactive Forms

No Angular, um formulário reativo é um modelo no TypeScript:

```ts
this.form = this.formBuilder.group({
  codigoMinisterio: [null, [Validators.required, MinisterioSaudeCodeValidator.validate]],
});
```

- `FormGroup`: o formulário inteiro.
- `FormControl`: cada campo.
- O template liga o campo com `formControlName="codigoMinisterio"`.

### 7.2 Validators

- `Validators.required`: valor vazio é inválido.
- `Validators.pattern(...)`: valida por expressão regular.
- **Validator customizado**: função que recebe um `AbstractControl` e devolve `null` (válido) ou
  um objeto de erro (inválido).

O validator implementado:

```ts
return /^\d{1,10}$/.test(String(value))
  ? null
  : { ministerioSaudeCodeInvalid: true };
```

- `\d`: dígito de 0 a 9.
- `{1,10}`: de 1 a 10 ocorrências.
- `^` e `$`: começo e fim do texto.
- `String(value)`: aceita tanto string (digitada) quanto número (vindo do banco).
- Vazio retorna `null` para não competir com o `required`; assim o usuário vê “Campo
  obrigatório”, e não a mensagem de formato.

### 7.3 Diretiva × validator × componente

| Conceito | Papel |
|---|---|
| Componente | tela, template e classe |
| Diretiva | comportamento aplicado a um elemento (`appDigitsOnly`) |
| Validator | regra que marca o controle como válido/inválido |

Chamar uma diretiva de “Validator” mistura os papéis. Por isso os nomes são diferentes.

### 7.4 `NgControl`

A diretiva injeta `NgControl`:

```ts
constructor(
  private readonly elementRef: ElementRef<HTMLInputElement>,
  private readonly control: NgControl
) {}
```

`NgControl` é a ponte com o formulário reativo. É o mesmo padrão usado por
`PositivoDirective` e `AlfanumericoDirective` no projeto.

### 7.5 `@HostListener`

```ts
@HostListener('input')
onInput(): void { ... }

@HostListener('blur')
onBlur(): void { ... }
```

- `input`: dispara a cada tecla/colagem.
- `blur`: quando o campo perde o foco; usado para marcar como “tocado” e exibir erros.

### 7.6 `setValue` com `emitEvent: false`

```ts
this.control.control?.setValue(digits, { emitEvent: false });
```

- `setValue` atualiza o controle.
- `emitEvent: false` evita disparar `valueChanges` de novo, prevenindo loops.
- Os validadores continuam rodando; o `pattern`/custom valida o valor já limpo.
- No Local da aplicação isso também evita disparar de novo o validador assíncrono de código
  duplicado a cada correção.

### 7.7 `dirty` e `touched`

- `dirty`: o usuário alterou o valor.
- `touched`: o usuário passou pelo campo (blur).
- Muitos validadores assíncronos só rodam se `control.dirty`; o `onBlur` ajuda a exibir o erro
  no momento certo.

### 7.8 `ControlValueAccessor` e a máscara

`ControlValueAccessor` é a interface que conecta um input customizado ao formulário. A máscara
do projeto implementa essa interface, mas o `onInput` dela permite letras:

```ts
let valor = this.elementRef.nativeElement.value.replace(/[^a-zA-Z0-9]/g, '');
```

Por isso a máscara **não** servia como bloqueio numérico. A nova diretiva usa `\D` (tudo que não
é dígito) e resolve o problema.

### 7.9 `inputmode="numeric"`

É uma dica para teclados móveis (abre o teclado numérico). **Não valida nada**; é só UX.

### 7.10 Cursor

Ao remover caracteres, o cursor pode “pular”. A diretiva recalcula uma posição válida com
`selectionStart` e `setSelectionRange`, para não atrapalhar quem digita no meio do número.

### 7.11 Por que não `type="number"`

- aceita `e`, `E`, `+`, `-`, `.`;
- o valor pode virar string vazia em entradas inválidas;
- varia entre navegadores;
- o `maxlength` é ignorado em `type="number"`.

Com `type="text"` + diretiva + validator, o comportamento é previsível.

---

## 8. Código final

### 8.1 Diretiva

`src/app/shared/directives/digits-only.directive.ts`

```ts
import { Directive, ElementRef, HostListener } from '@angular/core';
import { NgControl } from '@angular/forms';

@Directive({
  selector: 'input[appDigitsOnly]',
})
export class DigitsOnlyDirective {
  constructor(
    private readonly elementRef: ElementRef<HTMLInputElement>,
    private readonly control: NgControl
  ) {}

  @HostListener('input')
  onInput(): void {
    const input = this.elementRef.nativeElement;
    const maxLength = Number(input.getAttribute('maxlength')) || 10;
    const digits = input.value.replace(/\D/g, '').slice(0, maxLength);

    if (input.value !== digits) {
      const caret = Math.min(
        input.selectionStart ?? digits.length,
        digits.length
      );
      input.value = digits;
      input.setSelectionRange(caret, caret);
    }

    this.control.control?.setValue(digits, { emitEvent: false });
  }

  @HostListener('blur')
  onBlur(): void {
    this.control.control?.markAsTouched();
  }
}
```

### 8.2 Validator

`src/app/shared/validators/ministerio-saude-code.validator.ts`

```ts
import { AbstractControl, ValidationErrors } from '@angular/forms';

export class MinisterioSaudeCodeValidator {
  static validate(control: AbstractControl): ValidationErrors | null {
    const value = control.value;

    if (value === null || value === undefined || value === '') {
      return null;
    }

    return /^\d{1,10}$/.test(String(value))
      ? null
      : { ministerioSaudeCodeInvalid: true };
  }
}
```

### 8.3 Registro no módulo

`src/app/shared/directives/directives.module.ts`

```ts
import { DigitsOnlyDirective } from './digits-only.directive';

@NgModule({
  declarations: [
    // ...
    DigitsOnlyDirective,
  ],
  exports: [
    // ...
    DigitsOnlyDirective,
  ],
})
export class DirectivesModule { }
```

O `SharedModule` já exporta o `DirectivesModule`, então as telas não precisam importar nada extra.

### 8.4 Formulários

```ts
// Tipo Dose e Local de atendimento
codigoMinisterio: [
  null,
  [Validators.required, MinisterioSaudeCodeValidator.validate],
],

// Local da aplicação (mantém o validador assíncrono)
codigoMinisterio: [
  null,
  [Validators.required, MinisterioSaudeCodeValidator.validate],
  this.validadorCodigoMinisterioExistente.bind(this),
],
```

### 8.5 Template

```html
<input formControlName="codigoMinisterio" required maxlength="10"
       inputmode="numeric" appDigitsOnly />

<nab-error *ngIf="formControlCodigo.hasError('ministerioSaudeCodeInvalid')" i18n>
  {{ HINT_ERRO_CODIGO_MINISTERIO_INVALIDO }}
</nab-error>
```

No Local da aplicação, o `appVacinasMask` foi removido e o `maxlength` passou de 20 para 10.

### 8.6 Mensagem

`src/app/shared/mensagens-notificacao.ts`

```ts
HINT_ERRO_CODIGO_MINISTERIO_INVALIDO =
  'Código inválido. Informe apenas números, com até 10 dígitos.',
```

Nos componentes, exposta como:

```ts
public readonly HINT_ERRO_CODIGO_MINISTERIO_INVALIDO =
  $localize`${MensagensNotificacao.HINT_ERRO_CODIGO_MINISTERIO_INVALIDO}`;
```

---

## 9. Armadilhas e pontos de atenção

1. **Local da aplicação não valida o formulário no salvar.** A diretiva é o que impede o valor
   inválido de chegar ao back. Um validator sozinho não bastaria nessa tela.
2. **Dois donos do valor.** Não use `appVacinasMask` junto com `appDigitsOnly` no mesmo input:
   ambos manipulam o controle. Por isso a máscara foi removida do campo.
3. **`emitEvent: false`.** Sem isso, o `setValue` da diretiva poderia reentrar no `valueChanges`
   e criar loop, principalmente com o validador assíncrono.
4. **I18n.** A mensagem nova entra na extração do `ng xi18n`; as traduções `en`/`es` ficam
   pendentes até o próximo ciclo. O `pt` usa o texto fonte.
5. **Zeros à esquerda.** O banco é numérico: `"001"` vira `1`. Se o negócio precisar preservar
   zeros, o campo teria de ser texto — não é o caso.
6. **Valores antigos com mais de 10 dígitos.** Como o banco aceita até 38, um registro legado
   maior que 10 seria marcado como inválido na edição. O limite de 10 é a regra atual de tela.
7. **CRLF × LF.** Os arquivos alterados foram normalizados para LF (padrão do `.editorconfig`),
   reduzindo o ruído de fim de linha no `git diff`. O repositório ainda tem outros arquivos com
   CRLF pendente, de antes deste trabalho.
8. **Back continua devolvendo 500** se alguém burlar o front. Melhorar isso para 400 com mensagem
   amigável é uma melhoria separada.

---

## 10. Checklist de teste manual

- [ ] digitar letras → não entra;
- [ ] colar `12a3` → vira `123`;
- [ ] colar `abc` → fica vazio;
- [ ] 10 dígitos são aceitos;
- [ ] o 11º dígito é bloqueado;
- [ ] campo vazio → “Campo obrigatório”;
- [ ] letra via autofill/script → mensagem “Código inválido…”;
- [ ] salvar e editar nas três telas;
- [ ] registro com código existente continua carregando e salvando.

---

## 11. Perguntas de revisão

1. Qual a diferença entre diretiva e validator?
2. Por que `Validators.pattern` sozinho não resolveu?
3. Por que a máscara antiga aceitava letras?
4. O que `emitEvent: false` evita?
5. Por que o Local da aplicação precisava da diretiva mesmo com o validator?
6. Por que o back devolvia 500 em vez de 400?
7. O que aconteceria se o banco fosse `NUMBER(38,0)` e o Java usasse `Long` com 25 dígitos?
8. Por que `type="number"` não foi a escolha?
9. O que `String(value)` resolve no validator?
10. Por que a mensagem de vazio fica com o `required` e não com o validator?

---

## 12. Referências no projeto

- `src/app/shared/directives/digits-only.directive.ts`
- `src/app/shared/validators/ministerio-saude-code.validator.ts`
- `src/app/shared/directives/directives.module.ts`
- `src/app/shared/mensagens-notificacao.ts`
- `src/app/modules/tipo-dose/salvar-tipo-dose-form/`
- `src/app/modules/local-da-aplicacao/local-da-aplicacao-form/`
- `src/app/modules/local-atendimento/local-atendimento-form/`
- `src/app/shared/directives/vacinas-mask.directive.ts` (para comparar o CVA)
- `vacinas-back/vacinas-server-service/src/main/java/br/com/mv/html5/saudepublica/vacinas/advice/ValidationRulesExceptionAdvice.java` (tratador genérico)
- Angular Reactive Forms: https://v10.angular.io/guide/reactive-forms
- Validators: https://v10.angular.io/api/forms/Validators
- Attribute directives: https://v10.angular.io/guide/attribute-directives

---

**Resumo de 30 segundos:** o campo é numérico no banco e `Long` no Java; o front não filtrava
nada. A diretiva `DigitsOnlyDirective` impede letra na entrada, e o validator
`MinisterioSaudeCodeValidator` garante a regra `^\d{1,10}$` como rede de segurança. O limite de
10 é regra de tela; o banco é `NUMBER(38,0)`.
