# Ensino — Limites de campos, máscara e anexo do protocolo (VACINAS)

**Caso real:** chamado de QA da versão **24.6.10-RC.4**, ambiente Oracle, telas de cadastro do
sistema **Vacinas**.

**Sintomas do chamado original:**

- campos de texto aceitavam mais caracteres do que o back/banco permitiam;
- campos numéricos aceitavam valores enormes e o salvamento falhava sem mensagem ou com mensagem
  genérica;
- ao exceder o limite, aparecia “Campo obrigatório” indevidamente em alguns campos;
- a grid de esquema de dose não concluía a edição quando o valor era gigante;
- o protocolo de imunobiológico retornava erro de integridade ao enviar um anexo vazio.

**Escopo deste documento:** toda a demanda — limites de campos, correção da máscara e validação
do anexo do protocolo.

**Status no momento deste registro:**

- limites de campos e correção da máscara: **implementados no front**;
- anexo do protocolo: **solução front-only definida**, com aplicação pendente para a próxima
  etapa.

Este documento existe para estudo posterior. Ele explica o problema, o caminho do dado, as
alternativas, os conceitos e o código final/proposto.

---

## 1. O problema original

O QA encontrou o mesmo tipo de falha em várias telas:

| # | Tela / campo | O que acontecia | Causa principal |
|---|---|---|---|
| 1 | Apresentação > Código MS | aceitava mais que o limite; não salvava sem sinalizar | `type=number` sem limite; valor virava `Infinity` |
| 2 | Apresentação > Quantidade | aceitava mais; mensagem não tratada | sem `max`; validador assíncrono enviava `Infinity` |
| 3 | Fornecedor > Razão social | aceitava mais; mensagem genérica | sem `maxlength`; banco 200 |
| 4 | Fornecedor > Nome fantasia | aceitava mais; mensagem genérica | front 400, `@Size` 250, banco 200 |
| 5 | Fornecedor > E-mail | aceitava mais; mensagem genérica | sem `maxlength`; `@Size` 100 |
| 6 | Imunobiológico > Imunobiológico | aceitava mais; mensagem não tratada | front 400, back/banco 250 |
| 7 | Local da aplicação > Sigla | aceitava mais; mensagem genérica | front 20, banco 10 |
| 8 | Local de atendimento > Descrição | aceitava mais; mensagem genérica | front 100, back/banco 30 |
| 9 | Protocolo > Protocolo de imunização | aceitava mais; mensagem genérica | sem `maxlength`/validator; back/banco 200 |
| 10 | Permissões > Perfil de Acesso | aceitava mais; mensagem genérica | front 400, banco 200 |
| 11 | Esquema de dose > Idade/Ordem | 310+ caracteres geravam “Campo obrigatório” | `Infinity` virava `null` no JSON |
| 12 | Incompatibilidade > Intervalo | 310+ caracteres geravam “Campo obrigatório” | mesmo fluxo `Infinity` → `null` |
| 13 | Grid de esquema de dose | edição não concluía e não mostrava mensagem | mesmo overflow numérico |

O resultado esperado pelo QA era simples:

> Limitar o campo no front em conformidade com o limite do back, permitindo salvar as informações
> com sucesso.

---

## 2. O caminho do dado

```
Tela Angular (Reactive Forms)
  -> Service (MVCommonsGenericService / HttpClient)
  -> POST/PUT /vacinas/api/...
  -> Controller (@RestController)
  -> Business (@Service)
  -> Repository (JpaRepository)
  -> Hibernate/JPA
  -> Oracle (schema DBAVAC)
```

Cada camada tem um limite ou uma validação:

| Camada | Exemplo | O que valida |
|---|---|---|
| HTML | `maxlength="200"` | impede digitar/colar além do tamanho |
| Angular | `Validators.maxLength(200)` | marca o formulário inválido |
| Java DTO | `@Size(max = 200)` | valida o payload |
| Java Entity | `@Size(max = 200)` | valida antes do JPA gravar |
| Oracle | `VARCHAR2(200)` | limite físico do banco |

A regra de ouro:

> O limite do front deve ser o **menor** entre o `@Size`/`@Max` do back e o tamanho da coluna no
> banco. Se o front permitir mais, o usuário só descobre o problema no salvamento.

---

## 3. Recorte A — Limites de campos no front

### 3.1 O que o QA via

Em campos de texto, o front deixava digitar além do limite. Ao salvar:

- às vezes aparecia “Restrição de integridade ao tentar persistir os dados”;
- às vezes “Erro interno no servidor”;
- às vezes nada aparecia.

Em campos numéricos, o problema era mais grave: o valor gigante virava `Infinity` e depois `null`.

### 3.2 Por que `maxlength` sozinho não basta

`maxlength` é um atributo do HTML. Ele impede a digitação/colagem no navegador, mas:

- não atualiza sozinho a validação do formulário reativo;
- pode ser burlado por `patchValue`, autofill, script ou chamada de API;
- não existe para `type="number"` (o navegador ignora `maxlength` em número).

Por isso a solução usa **os dois**:

```html
<input maxlength="200" />
```

```ts
campo: [null, [Validators.required, Validators.maxLength(200)]]
```

- `maxlength`: impede o usuário de digitar além.
- `Validators.maxLength`: garante que o formulário fique inválido se o valor chegar por outro
  caminho.
- A mensagem `maxlength` mostra `atual/limite`.

### 3.3 Limites aplicados

| Tela | Campo | Limite correto |
|---|---|---|
| Fornecedor | Razão social | 200 |
| Fornecedor | Nome fantasia | 200 |
| Fornecedor | E-mail | 100 |
| Imunobiológico | Imunobiológico | 250 |
| Imunobiológico | Sigla | 10 |
| Imunobiológico | Abreviatura | 100 |
| Local da aplicação | Sigla | 10 |
| Local de aplicação | Descrição | 100 (mantido) |
| Local de atendimento | Descrição | 30 |
| Local de atendimento | Observações | 100 |
| Protocolo | Protocolo de imunização | 200 |
| Protocolo | Descrição do anexo | 100 |
| Permissões | Perfil de Acesso | 200 |
| Apresentação | Código MS | 10 dígitos |
| Apresentação | Quantidade | 10 dígitos |

### 3.4 Constantes compartilhadas

Arquivo: `src/app/shared/constants/limites-campos.ts`

```ts
export const LIMITES_CAMPOS = {
  apresentacao: {
    codigoMinisterioDigitos: 10,
    quantidadeDigitos: 10,
  },
  fornecedor: {
    razaoSocial: 200,
    nomeFantasia: 200,
    email: 100,
  },
  imunobiologico: {
    sigla: 10,
    nome: 250,
    abreviatura: 100,
    codigoMinisterioDigitos: 10,
  },
  localAplicacao: {
    sigla: 10,
    descricao: 100,
    codigoMinisterioDigitos: 10,
  },
  localAtendimento: {
    descricao: 30,
    observacoes: 100,
    codigoMinisterioDigitos: 10,
  },
  protocolo: {
    descricao: 200,
    anexoDescricao: 100,
  },
  perfilAcesso: {
    descricao: 200,
  },
  esquemaDose: {
    valorMaximo: 2_000_000_000,
    digitos: 10,
  },
  incompatibilidade: {
    valorMaximo: 2_000_000_000,
    digitos: 10,
  },
} as const;
```

**Por que centralizar?**

- evita número mágico repetido em cada tela;
- se o back mudar, altera-se em um lugar;
- fica fácil revisar se front e back estão alinhados.

### 3.5 Campos numéricos — o problema do `Infinity`

Em `<input type="number">`, o `maxlength` é ignorado. Ao digitar 310 caracteres:

1. o navegador mantém o valor no DOM;
2. o Angular converte com `parseFloat`;
3. o valor vira `Infinity`;
4. `JSON.stringify(Infinity)` vira `null`;
5. o back recebe `null`;
6. o `@NotNull` dispara **“Campo obrigatório”**, mesmo o campo não estando vazio.

Nos campos opcionais, o `null` passa e a alteração pode não concluir. Nos obrigatórios, a mensagem
é falsa.

Além disso, o validador assíncrono de duplicidade da Apresentação recebia `quantidade=Infinity`
na query. O back tentava converter para `Long`, falhava, e o formulário ficava travado sem
mensagem.

### 3.6 Diretiva `appLimiteNumerico`

Arquivo: `src/app/shared/directives/limite-numerico.directive.ts`

```ts
import {
  Directive,
  ElementRef,
  forwardRef,
  HostListener,
  Input,
} from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';

@Directive({
  selector: 'input[appLimiteNumerico]',
  providers: [
    {
      provide: NG_VALUE_ACCESSOR,
      useExisting: forwardRef(() => LimiteNumericoDirective),
      multi: true,
    },
  ],
})
export class LimiteNumericoDirective implements ControlValueAccessor {
  @Input() maxDigitos = 10;

  private onChange: (valor: number | null) => void = () => { };
  private onTouched: () => void = () => { };

  constructor(private readonly el: ElementRef<HTMLInputElement>) { }

  writeValue(valor: any): void {
    this.el.nativeElement.value =
      valor === null || valor === undefined ? '' : String(valor);
  }

  registerOnChange(fn: (valor: number | null) => void): void {
    this.onChange = fn;
  }

  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }

  setDisabledState(isDisabled: boolean): void {
    this.el.nativeElement.disabled = isDisabled;
  }

  @HostListener('input')
  onInput(): void {
    const input = this.el.nativeElement;
    const digitos = input.value.replace(/\D/g, '').slice(0, this.maxDigitos);
    input.value = digitos;
    this.onChange(digitos === '' ? null : Number(digitos));
  }

  @HostListener('blur')
  onBlur(): void {
    this.onTouched();
  }
}
```

**O que essa diretiva faz:**

- remove tudo que não é dígito (`\D`);
- corta em `maxDigitos`;
- entrega um `number` de verdade ao formulário;
- impede o `Infinity`;
- chama `onTouched` no blur para o Angular exibir os erros.

**Por que `ControlValueAccessor`?**

O Angular usa um `ControlValueAccessor` para ligar o input ao `FormControl`. A diretiva fornece
o próprio accessor (`NG_VALUE_ACCESSOR`) e passa a ser a dona da conversão. É o mesmo padrão da
máscara do projeto.

### 3.7 Validador de inteiro

Arquivo: `src/app/shared/validators/vacinas-validators.ts`

```ts
static numeroInteiro(control: AbstractControl): { [key: string]: any } | null {
  const valor = control.value;
  if (valor === null || valor === undefined || valor === '') {
    return null;
  }
  const numero = Number(valor);
  return Number.isFinite(numero) && Number.isInteger(numero)
    ? null
    : { numeroInvalido: true };
}
```

**Por que existe mesmo com a diretiva?**

- a diretiva cobre digitação/colagem;
- o validador cobre `patchValue`, API, autofill e valores legados;
- `Number.isFinite` rejeita `Infinity` e `NaN`;
- `Number.isInteger` rejeita decimais.

### 3.8 Exemplo no Esquema de dose

Antes:

```ts
idadeRecomendada: [null, [Validators.required, Validators.min(0)]],
intervaloMinimo: [null, [Validators.min(0)]],
ordemAplicacao: [null, [Validators.required, Validators.min(0)]],
```

Depois:

```ts
private readonly VALIDADORES_NUMERICOS = [
  Validators.min(0),
  Validators.max(LIMITES_CAMPOS.esquemaDose.valorMaximo),
  VacinasValidators.numeroInteiro,
];

idadeRecomendada: [
  null,
  [Validators.required, ...this.VALIDADORES_NUMERICOS],
],
intervaloMinimo: [null, [...this.VALIDADORES_NUMERICOS]],
ordemAplicacao: [
  null,
  [Validators.required, ...this.VALIDADORES_NUMERICOS],
],
```

No template:

```html
<input
  type="number"
  min="0"
  max="2000000000"
  appLimiteNumerico
  [maxDigitos]="10"
  formControlName="idadeRecomendada"
  required />
```

**Por que `Validators.max(2_000_000_000)`?**

O back tem `@Max(2_000_000_000)` nesses campos. Qualquer valor acima disso seria rejeitado.
O front passa a mostrar “Valor máximo permitido: 2.000.000.000” em vez de “Campo obrigatório”.

### 3.9 Validador assíncrono da Apresentação

A quantidade tem um validador que consulta o back para saber se já existe. Ele precisa de guarda:

```ts
private validadorCampoDuplicado(controlName: string, control: AbstractControl) {
  if (
    control.value === null ||
    control.value === undefined ||
    !Number.isFinite(Number(control.value))
  ) {
    return of(null);
  }

  const filtroApresentacao = new ApresentacaoFiltro();
  filtroApresentacao[controlName] = control.value;
  const queryFiltro = new QueryPage({ page: 0 });

  return timer(500).pipe(
    switchMap(() =>
      this.entidadeService.listarTodosPaginado(filtroApresentacao, queryFiltro)
    ),
    map((res) => {
      // lógica de duplicidade
    }),
    catchError(() => of(null))
  );
}
```

**Por que?**

- se o valor não é número finito, nem chama o back;
- se o back falhar, o formulário não fica travado;
- evita `quantidade=Infinity` na query.

### 3.10 Conceitos do recorte A

#### Reactive Forms

- `FormGroup`: o formulário inteiro.
- `FormControl`: cada campo.
- `formControlName`: liga o template ao control.
- `valid`: true quando todos os controles válidos estão válidos.
- `pending`: true quando um validador assíncrono ainda está rodando.

#### `Validators`

- `required`: valor vazio é inválido.
- `maxLength`: tamanho máximo.
- `max`: valor numérico máximo.
- `pattern`: expressão regular.
- validador customizado: função que devolve `null` ou um objeto de erro.

#### `Infinity`, `NaN` e JSON

- `parseFloat` de um número gigante pode virar `Infinity`.
- `Infinity` não é representável em JSON; vira `null`.
- O back recebe `null` e dispara `@NotNull`.

#### `emitEvent`

- `setValue(value, { emitEvent: false })` atualiza o controle sem reemitir `valueChanges`.
- Evita loop em diretivas que escrevem no próprio campo.

#### Async validators e `PENDING`

- Enquanto o validador assíncrono roda, o controle fica `PENDING`.
- `form.valid` fica `false`.
- Um botão ligado a `!form.valid` fica desabilitado durante a consulta.
- Isso é correto para consistência, mas pode atrasar a UX; em alguns casos é melhor separar a
  validação assíncrona do `valid`.

---

## 4. Recorte B — O bug da máscara

### 4.1 O sintoma

No campo de CNPJ, ao digitar além do tamanho da máscara:

- o campo visual parecia cortado;
- o valor do formulário continuava com os caracteres extras;
- o validador de CNPJ via o valor maior e acusava “CNPJ inválido”;
- ao apertar mais uma tecla, o erro aparecia.

### 4.2 A causa

Arquivo: `src/app/shared/directives/vacinas-mask.directive.ts`

Antes:

```ts
@HostListener('input', ['$event'])
onInput(event: Event) {
  const tamanhoMaximoDoValor = this.appVacinasMask.replace(/\D/gi, '').length;
  let valor = this.elementRef.nativeElement.value.replace(/[^a-zA-Z0-9]/g, '');

  this.onChange(valor); // recebe o valor inteiro, sem cortar
  this.elementRef.nativeElement.value = this.aplicarMascara(valor, this.appVacinasMask);

  event.preventDefault();
  event.stopPropagation();
}
```

O `aplicarMascara` corta o **display**, mas o `onChange` já recebeu o valor inteiro. O formulário
fica com mais caracteres do que o campo mostra.

Além disso, `tamanhoMaximoDoValor` usava `\D`, que conta apenas dígitos. A máscara alfanumérica do
CNPJ usa `A`, então o cálculo estava errado.

### 4.3 A correção

```ts
@HostListener('input', ['$event'])
onInput(event: Event) {
  const capacidade = (this.appVacinasMask.match(/[9A]/gi) || []).length;
  const valor = this.elementRef.nativeElement.value
    .replace(/[^a-zA-Z0-9]/g, '')
    .slice(0, capacidade);

  this.onChange(valor);
  this.elementRef.nativeElement.value = this.aplicarMascara(valor, this.appVacinasMask);

  event.preventDefault();
  event.stopPropagation();
}
```

E no `writeValue`:

```ts
writeValue(inputValue: any): void {
  if (nonNull(inputValue)) {
    const capacidade = (this.appVacinasMask.match(/[9A]/gi) || []).length;
    const valor = String(inputValue)
      .replace(/[^a-zA-Z0-9]/g, '')
      .slice(0, capacidade);
    this.elementRef.nativeElement.value = this.aplicarMascara(
      valor,
      this.appVacinasMask
    );
  } else {
    this.elementRef.nativeElement.value = '';
  }
}
```

### 4.4 Conceitos do recorte B

#### `ControlValueAccessor`

Interface que liga um input customizado ao formulário. A máscara implementa essa interface.

#### Valor visual × valor do control

- O input mostra o valor formatado (`11.222.333/4444-55`).
- O control pode guardar o valor cru (`11222333444455`).
- Os dois precisam ter o mesmo tamanho lógico; senão o validador vê um valor e o usuário vê outro.

#### Máscara não é validação

A máscara formata e limita, mas não sabe se o CNPJ é válido. A validação é outra responsabilidade.

#### `[9A]`

- `9` = posição de dígito.
- `A` = posição alfanumérica.
- `match(/[9A]/gi)` conta quantas posições a máscara tem.

---

## 5. Recorte C — Anexo do protocolo de imunobiológico

### 5.1 O payload real

O QA enviou:

```http
------WebKitFormBoundary...
Content-Disposition: form-data; name="file"; filename="TSTEASASASA.TXT"
Content-Type: text/plain


------WebKitFormBoundary...
Content-Disposition: form-data; name="content"; filename="blob"
Content-Type: application/octet-stream

{"excluido":0,"id":null,"descricao":"AAAA...CHIDIORI", ...}
------WebKitFormBoundary...--
```

O JSON tinha:

- `descricao` com **200 caracteres** (no limite, portanto não era o problema);
- `anexoDescricao`: `TSTEASASASA.TXT`;
- `anexoConteudo`: `null`;
- `anexoTipo`: `null`;
- `imunobiologico.id`: `1402`;
- `unidadeAtendimento.id`: `1`.

A parte `file` existia, mas estava **vazia (0 bytes)**.

### 5.2 A resposta

```json
{
  "status": 400,
  "message": "could not execute statement; SQL [n/a]; constraint [null]; nested exception is org.hibernate.exception.ConstraintViolationException: could not execute statement",
  "error": "Bad Request",
  "path": "/vacinas/api/imunobiologicos-protocolos",
  "errors": [{ "message": "Restrição de integridade ao tentar persistir os dados" }]
}
```

### 5.3 Onde o dado mora

Tabela `DBAVAC.PROTOCOLO_IMUNOBIOLOGICO`:

| Coluna | Tipo | Regra |
|---|---|---|
| `DS_PROTOCOLO_IMUNOBIOLOGICO` | `VARCHAR2(200)` | `NOT NULL` |
| `LO_ANEXO_PROTOCOLO` | `BLOB` | `NOT NULL` |
| `DS_ANEXO_PROTOCOLO` | `VARCHAR2(100)` | `NOT NULL` |
| `TP_ANEXO_PROTOCOLO` | `VARCHAR2(100)` | `NOT NULL` |

### 5.4 O caminho do arquivo no back

```java
public void create(final String content, final MultipartFile file, Optional<Long> id) {
    final ProtocoloImunobiologicoDTO resource =
        objectMapper.readValue(content, ProtocoloImunobiologicoDTO.class);

    if (nonNull(file)) {
        resource.setAnexoTipo(file.getContentType());
        resource.setAnexoConteudo(file.getBytes());
    }

    id.ifPresent(resource::setId);
    this.create(resource);
}
```

- Se o arquivo é `null`, o DTO fica com `anexoConteudo = null`.
- Se o arquivo existe mas está vazio, `getBytes()` devolve `byte[0]`.
- `byte[0]` **não é null**.

A regra atual:

```java
p -> isNull(p.getAnexoConteudo()) && isNull(p.getId())
```

Como `byte[0]` não é null, a regra passa. O banco então reclama do BLOB vazio/nulo.

### 5.5 Por que a mensagem é genérica

O `ValidationRulesExceptionAdvice` trata `DataIntegrityViolationException`/`TransactionSystemException`
com a mensagem fixa:

```java
final String message = "Restrição de integridade ao tentar persistir os dados";
```

Ele não mostra qual constraint falhou. Por isso o QA vê a mensagem genérica.

### 5.6 A correção front-only definida

Escopo escolhido: **somente front**. A API direta continua retornando o 400 genérico.

#### Mensagens

```ts
private readonly MSG_ANEXO_VAZIO = $localize`O arquivo selecionado está vazio.`;
private readonly MSG_ANEXO_PDF = $localize`O anexo deve ser um arquivo PDF.`;
private readonly MSG_ANEXO_OBRIGATORIO = $localize`Selecione um arquivo PDF para o anexo.`;
```

#### Método de validação

```ts
private validarAnexo(file: File): string | null {
  if (file.size === 0) {
    return this.MSG_ANEXO_VAZIO;
  }

  if (!this.ehArquivoPdf(file)) {
    return this.MSG_ANEXO_PDF;
  }

  return null;
}

private ehArquivoPdf(file: File): boolean {
  return file.type === 'application/pdf' ||
    (file.type === '' && file.name.toLowerCase().endsWith('.pdf'));
}
```

#### `onFileChange` com guard clauses

```ts
public onFileChange(): void {
  const file: File = firstOf(this.fileInput.nativeElement.files);

  if (!file) {
    return;
  }

  const mensagem = this.validarAnexo(file);

  if (mensagem) {
    this.limparSelecaoAnexoInvalida();
    this.mostrarMsgErro(mensagem);
    return;
  }

  this.formControlAnexoDescricao.patchValue(file.name);
  this.formControlAnexoConteudo.patchValue(file);
}

private limparSelecaoAnexoInvalida(): void {
  this.fileInput.nativeElement.value = '';

  if (!this.isEdit) {
    this.formControlAnexoDescricao.patchValue(null);
    this.formControlAnexoConteudo.patchValue(null);
  }
}
```

#### Guarda no `salvar()`

```ts
public salvar() {
  if (!this.isEdit && !this.formControlAnexoConteudo.value) {
    this.mostrarMsgErro(this.MSG_ANEXO_OBRIGATORIO);
    return;
  }

  this.iniciarLoading();
  this.disableInputsOnLoading();
  // fluxo atual
}
```

### 5.7 Por que guard clauses e não `switch`

O `switch` exige um valor único para comparar. O anexo é uma **sequência de validações**:

1. veio arquivo?
2. está vazio?
3. é PDF?

Guard clauses:

```ts
if (!file) {
  return;
}

const mensagem = this.validarAnexo(file);

if (mensagem) {
  this.limparSelecaoAnexoInvalida();
  this.mostrarMsgErro(mensagem);
  return;
}

this.formControlAnexoDescricao.patchValue(file.name);
this.formControlAnexoConteudo.patchValue(file);
```

Switch exigiria classificar antes:

```ts
type StatusAnexo = 'SEM_ARQUIVO' | 'VAZIO' | 'TIPO_INVALIDO' | 'VALIDO';

switch (this.classificarAnexo(file)) {
  case 'SEM_ARQUIVO':
    return;
  case 'VAZIO':
    // ...
    return;
  case 'TIPO_INVALIDO':
    // ...
    return;
  case 'VALIDO':
    // ...
    return;
}
```

**Quando usar cada um:**

| Estrutura | Melhor para |
|---|---|
| `if` com `return` | validações sequenciais, erros que devem sair cedo |
| `switch` | escolher entre muitos valores discretos |
| mapa de estratégias | muitas regras independentes e extensíveis |
| `switch (true)` | evitar; é anti-padrão e confunde leitura |

A escolha profissional aqui é **guard clauses + validação extraída**.

### 5.8 Novo × edição

- **Novo:** arquivo é obrigatório. Arquivo vazio ou não PDF limpa os campos e bloqueia o save.
- **Edição:** o anexo antigo pode ser mantido. Se o usuário selecionar um arquivo inválido, apenas
  a seleção é limpa; o anexo existente não é apagado.

### 5.9 Limitação do front-only

A correção impede o caso pela tela, mas não protege a API:

- Postman/curl ainda podem enviar arquivo vazio;
- o back continua devolvendo o 400 genérico;
- a validação definitiva seria no `ProtocoloImunobiologicoBusiness`, com `file.isEmpty()` e
  validação de MIME.

Exemplo do que seria feito no back (não executado nesta demanda):

```java
if (nonNull(file)) {
    if (file.isEmpty()) {
        throw new ValidationException("O arquivo do anexo está vazio.");
    }
    if (!"application/pdf".equalsIgnoreCase(file.getContentType())) {
        throw new ValidationException("O anexo deve ser um arquivo PDF.");
    }
    resource.setAnexoTipo(file.getContentType());
    resource.setAnexoConteudo(file.getBytes());
}
```

### 5.10 Conceitos do recorte C

#### `File`

Objeto do navegador com:

- `name`: nome do arquivo;
- `size`: tamanho em bytes;
- `type`: MIME informado pelo sistema operacional/navegador.

`size === 0` significa arquivo vazio.

#### MIME × extensão

- `file.type` vem do sistema, não do conteúdo.
- Pode vir vazio em alguns sistemas.
- `.pdf` no nome não garante PDF de verdade.
- O front só faz uma validação superficial; o back precisaria validar conteúdo se fosse crítico.

#### `accept="application/pdf"`

É uma dica para o seletor de arquivos. **Não é validação** e pode ser burlado.

#### `FormData` e multipart

O front monta:

```ts
const formData = new FormData();
formData.append('file', file, fileName);
formData.append('content', new Blob([JSON.stringify(resource.clean())]));
```

- `file`: binário.
- `content`: JSON com os demais campos.
- O back lê os dois com `@RequestPart`.

#### Validação pura × efeitos colaterais

- `validarAnexo` só decide e devolve mensagem.
- `onFileChange` aplica os efeitos (limpar, mostrar mensagem, preencher campos).
- Separar as duas coisas facilita teste e leitura.

#### `ViewChild` e `ElementRef`

```ts
@ViewChild('imgFileInput') fileInput: ElementRef;
```

Permite acessar o input de arquivo no TypeScript para ler `files` e limpar `value`.

#### `patchValue`

Atualiza o controle sem passar pelo usuário. Usado para preencher a descrição e o conteúdo do
anexo.

#### `isEdit`

Diferencia novo de edição. Em edição, o anexo existente não deve ser apagado por uma seleção
inválida.

---

## 6. O que foi executado

| Item | Status | Arquivos principais |
|---|---|---|
| Constantes de limites | Implementado | `shared/constants/limites-campos.ts` |
| Diretiva numérica | Implementado | `shared/directives/limite-numerico.directive.ts` |
| Validador de inteiro | Implementado | `shared/validators/vacinas-validators.ts` |
| Limites de texto | Implementado | Apresentação, Fornecedor, Imunobiológico, Locais, Protocolo, Permissões |
| Limites numéricos | Implementado | Apresentação, Esquema de dose, Incompatibilidade |
| Correção da máscara | Implementado | `shared/directives/vacinas-mask.directive.ts` |
| Anexo do protocolo | Solução definida | `protocolo-imunobiologico-form.component.ts` |

Validações executadas:

- `tsc --noEmit`: sem erros nos arquivos alterados;
- `ng build`: `EXIT=0`;
- `ng build --prod`: `EXIT=0`;
- lint: sem erros novos nos arquivos alterados; o repositório já possuía erros antigos.

---

## 7. Conceitos transversais

### 7.1 Defesa em profundidade

- Front impede o usuário de enviar errado.
- Back valida de novo, porque a API pode ser chamada diretamente.
- Banco garante a integridade final.

Nesta demanda, o front foi a primeira camada; o back ficou como melhoria separada.

### 7.2 Fonte única de verdade

Os limites ficaram em `LIMITES_CAMPOS`. Isso reduz divergência entre telas.

### 7.3 DDL × entidade × front

Sempre conferir os três:

- DDL/changelog: tamanho real da coluna;
- entidade Java: `@Size`/`@Max`;
- front: `maxlength`/`Validators`.

Se um estiver diferente, o usuário descobre no salvamento.

### 7.4 UX de validação

- erro perto do campo é melhor que mensagem genérica;
- não bloquear o botão por causa de validação assíncrona desnecessária;
- mostrar o limite (`atual/limite`) ajuda o usuário;
- em edição, não destruir dados existentes por causa de uma seleção inválida.

### 7.5 Testes

- valor no limite;
- limite + 1;
- 310 caracteres;
- colar;
- editar registro existente;
- chamada direta na API;
- arquivo vazio/não PDF/PDF válido.

---

## 8. Alternativas avaliadas

| Alternativa | Vantagem | Problema |
|---|---|---|
| Só `maxlength` | simples | não protege `patchValue`/API; ignorado em `type=number` |
| Só `Validators` | protege o formulário | não impede digitar |
| Só validação no back | fonte de verdade | UX ruim; erro só no salvamento |
| `type="number"` sem diretiva | nativo | aceita `e`, `+`, `-`, `.`; `maxlength` ignorado |
| `switch` para validar anexo | parece organizado | exige enum/classificação; over-engineering para 3 regras |
| `switch (true)` | reduz `if` visualmente | anti-padrão; difícil de ler/manter |
| Mapa de estratégias | extensível | complexo para o tamanho atual |
| Guard clauses + validador extraído | legível, testável, simples | exige um método a mais |

---

## 9. Armadilhas e pontos de atenção

1. `type="number"` ignora `maxlength`.
2. `Infinity` vira `null` no JSON.
3. `@NotNull` no back gera “Campo obrigatório” falso quando o valor virou `null`.
4. Validador assíncrono deixa o controle `PENDING`; botão ligado a `form.valid` fica desabilitado.
5. Máscara que chama `onChange` antes de cortar deixa o control maior que o display.
6. `\D` não conta posições `A` de máscara alfanumérica; usar `[9A]`.
7. `file.type` pode vir vazio; validar extensão como fallback.
8. `accept` não é segurança.
9. Arquivo vazio não é `null`; a regra `isNull` não pega.
10. Em edição, limpar o anexo existente ao selecionar arquivo inválido quebra o update.
11. Front-only não protege chamadas diretas na API.
12. O advice genérico esconde a constraint real do banco.
13. CRLF × LF pode gerar diff gigante em arquivos antigos.

---

## 10. Checklist de teste manual

### Limites de texto

- [ ] digitar no limite e salvar;
- [ ] tentar digitar limite + 1;
- [ ] colar valor maior;
- [ ] editar registro existente;
- [ ] conferir mensagem `atual/limite`.

### Limites numéricos

- [ ] digitar 10 dígitos;
- [ ] tentar o 11º;
- [ ] digitar 310 caracteres;
- [ ] digitar `2000000001` no esquema de dose;
- [ ] conferir que não aparece “Campo obrigatório” falso;
- [ ] editar item da grid.

### Máscara

- [ ] CNPJ: digitar/colar além do tamanho;
- [ ] telefone/DDD;
- [ ] códigos mascarados;
- [ ] conferir o payload enviado.

### Protocolo

- [ ] arquivo vazio;
- [ ] arquivo `.TXT`;
- [ ] PDF válido;
- [ ] novo sem arquivo;
- [ ] edição com anexo existente;
- [ ] edição com arquivo inválido;
- [ ] conferir mensagens na tela.

### Build

- [ ] `ng build`;
- [ ] `ng build --prod`;
- [ ] lint dos arquivos alterados.

---

## 11. Perguntas de revisão

1. Por que `maxlength` sozinho não resolve?
2. Qual a diferença entre `maxlength` e `Validators.maxLength`?
3. Por que `type="number"` não respeita `maxlength`?
4. O que acontece com `Infinity` no `JSON.stringify`?
5. Por que o back responde “Campo obrigatório” quando o valor é `Infinity`?
6. O que é um `ControlValueAccessor`?
7. Por que a diretiva numérica precisa de `NG_VALUE_ACCESSOR`?
8. Qual a diferença entre valor visual e valor do control na máscara?
9. Por que `[9A]` é melhor que `\D` para contar a máscara?
10. Por que o arquivo vazio passa pela regra `isNull`?
11. Qual a diferença entre validar no front e validar no back?
12. Por que guard clause é melhor que `switch` neste caso?
13. Quando um `switch` seria a melhor escolha?
14. Por que o anexo não deve ser apagado em edição ao selecionar arquivo inválido?
15. O que o `accept="application/pdf"` realmente faz?
16. Por que a descrição de 200 caracteres não era a causa do erro?
17. O que seria necessário para a API também devolver uma mensagem amigável?

---

## 12. Referências no projeto

### Front

- `src/app/shared/constants/limites-campos.ts`
- `src/app/shared/directives/limite-numerico.directive.ts`
- `src/app/shared/directives/vacinas-mask.directive.ts`
- `src/app/shared/validators/vacinas-validators.ts`
- `src/app/modules/apresentacao/apresentacao-form/`
- `src/app/modules/fornecedor/fornecedor-form/`
- `src/app/modules/imunobiologico/`
- `src/app/modules/local-da-aplicacao/local-da-aplicacao-form/`
- `src/app/modules/local-atendimento/local-atendimento-form/`
- `src/app/modules/protocolo-imunobiologico/protocolo-imunobiologico-form/`
- `src/app/modules/permissoes-acesso/permissoes-acesso-form/`

### Back

- `vacinas-back/vacinas-server-business/src/main/java/br/com/mv/html5/saudepublica/vacinas/model/ProtocoloImunobiologico.java`
- `vacinas-back/vacinas-server-business/src/main/java/br/com/mv/html5/saudepublica/vacinas/business/ProtocoloImunobiologicoBusiness.java`
- `vacinas-back/vacinas-server-business/src/main/java/br/com/mv/html5/saudepublica/vacinas/business/rules/protocolo_imunobiologico/`
- `vacinas-back/vacinas-server-service/src/main/java/br/com/mv/html5/saudepublica/vacinas/advice/ValidationRulesExceptionAdvice.java`
- `vacinas-back/vacinas-server-business/src/main/resources/db/changelog/01/0/0/210503_0900.SPCAVAC-290.PROTOCOLO_IMUNOBIOLOGICO.yaml`

### Documento anterior

- `docs/ensino-validacao-codigo-ministerio.md`

### Links

- Angular Reactive Forms: https://v10.angular.io/guide/reactive-forms
- Validators: https://v10.angular.io/api/forms/Validators
- Attribute directives: https://v10.angular.io/guide/attribute-directives
- MDN File API: https://developer.mozilla.org/pt-BR/docs/Web/API/File
- MDN FormData: https://developer.mozilla.org/pt-BR/docs/Web/API/FormData

---

## 13. Resumo de 30 segundos

O chamado tinha três famílias de problema: limites de texto divergentes entre front e back, campos
numéricos sem limite que viravam `Infinity`/`null`, e uma máscara que deixava o valor do formulário
maior que o campo visual. A correção criou limites centralizados, uma diretiva numérica com
`ControlValueAccessor`, validadores e o ajuste da máscara. No protocolo, o erro não era a descrição
de 200 caracteres: era o anexo de 0 bytes violando o `BLOB NOT NULL`. A solução front-only valida
tamanho e tipo do arquivo, limpa a seleção inválida e usa guard clauses com uma função de validação
separada — mais legível e testável que `switch` para esse caso.
