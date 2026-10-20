# Exemplos aprovados

Exemplos para calibrar tom e formato. Os textos do cliente seguem o padrão da empresa:
texto corrido, sem bullets, com verbos no passado (ocorrência) e no presente (alteração).

---

## Implementação — exemplo oficial (Glosas por Procedimento)

```
LOCALIZAÇÃO: Faturamento / Auditoria e Controle de Recursos de Glosas / Lançamentos / Glosas por Procedimento (M_GLOSAS)

DESCRIÇÃO: Implementada validação na tela "Glosas por Procedimento" para indicar a obrigatoriedade de preenchimento do campo de justificativa no ato da reapresentação da glosa quando a configuração "Obrigar Justificativa na Reapresentação", realizada na tela "Parâmetros" (Faturamento / Auditoria e Controle de Recursos de Glosas / Configurações / Parâmetros - M_CONFIG_FFAG), estiver habilitada.

TICKET RELACIONADO: PROD-0000
```

---

## Problema / Qualidade — exemplo oficial (Geração e Liberação de Agendas)

```
LOCALIZAÇÃO: Atendimento / Central de Agendamento / Agendamentos / Geração e Liberação de Agendas (M_GERA_AGENDA)

OCORRÊNCIA: Ao acessar a tela "Geração e Liberação de Agenda" e acionar o botão < 2 - Exibir Geração Agenda > e posteriormente o botão < Pesquisar >, sem indicar parâmetros para a consulta, era exibida uma mensagem de erro que não deixava claro ao usuário o motivo pelo qual a consulta não poderia ser realizada.

ALTERAÇÃO: Ajustes na tela para que ao acionar o botão < Pesquisar > a mensagem apresentada oriente o usuário a informar as datas de início e fim do período a ser consultado, essas informações são os parâmetros mínimos necessários para a realização da pesquisa. Para essa ação, também podem ser utilizados os botões < Hoje >, < 7 Dias > e < 1 Mês >. Nesse caso, não é necessário informar o período, apenas acionar os botões.

TICKET RELACIONADO: SUP-00001 / SUP-00002 / PROD-000
```

---

## Problema / Qualidade — caso real (CACPORTAL-1301)

```
Cliente: FUNDO MUNICIPAL DE SAÚDE DE GASPAR - 3159

LOCALIZAÇÃO: Portal Cidadão / Tela de Login / Seleção de Perfil / Saída do Sistema < Sair > e Base de Dados (registro de informações e log de eventos)

OCORRÊNCIA: Usuários com mais de um perfil não conseguiam acessar o Portal, permanecendo na tela de login em loop. Em alguns momentos, ocorria erro ao registrar as informações no banco de dados do cliente. Ao acionar o botão < Sair >, o sistema não retornava à tela de login.

ALTERAÇÃO: O acesso ao Portal passa a direcionar corretamente o usuário com mais de um perfil para a escolha do perfil desejado, mantendo o acesso direto para usuários com um único perfil e retornando à tela pretendida quando a seleção ocorrer no meio do acesso. Ajustes na base de dados do cliente eliminam os erros de registro de informações. Ao acionar o botão < Sair >, o sistema retorna corretamente à tela de login.

TICKET RELACIONADO: CACPORTAL-1301
```

---

## Problema / Qualidade — caso real (SPODO-3492)

```
LOCALIZAÇÃO: Saúde Pública / Odontograma / Atendimento Odontológico (tela de inclusão de procedimentos do paciente em atendimento) e Base de Dados (vínculos de procedimentos)

OCORRÊNCIA: Ao incluir procedimentos para o paciente que estava sendo atendido, o sistema apresentava erro e não salvava o procedimento. O erro ocorria apenas para alguns pacientes, que possuíam registros antigos de procedimentos cancelados.

ALTERAÇÃO: O sistema passa a tratar corretamente os vínculos antigos de procedimentos cancelados, sem interromper a operação, e a inclusão de procedimentos no odontograma volta a funcionar normalmente. Ajustes na base de dados do cliente removem os vínculos antigos inconsistentes, eliminando os erros apresentados.

TICKET RELACIONADO: SPODO-3492
```

---

## Release técnico — exemplo de estrutura

```
RELEASE TÉCNICO — SUP-00000
Natureza: Qualidade
Branch / MR: fix/SUP-00000

CAUSA / CONTEXTO:
A listagem de procedimentos consultava a tabela sem filtrar o indicador de exclusão
lógica. A exclusão gravava o registro como excluído, mas a consulta continuava
retornando esses registros.

ALTERAÇÕES:
- ProcedimentoAmbulatorialRepositoryImpl: filtro de exclusão passou a ser aplicado
  por padrão quando o parâmetro de histórico não é enviado.
- listagem-procedimento-ambulatorial.component.ts: passa a enviar isHistorico=false.

COMPORTAMENTO:
- Antes: o registro era excluído, mas continuava aparecendo na consulta.
- Depois: o registro excluído deixa de ser exibido na listagem principal.

IMPACTO / RISCO:
- A tela de histórico do paciente continua exibindo registros cancelados.
- Não há migração nem alteração de dados.

COMO TESTAR:
1. Acessar a tela de Procedimento Ambulatorial e pesquisar um procedimento.
2. Excluir o procedimento e confirmar a operação.
3. Pesquisar novamente e confirmar que o registro não é exibido.

OBSERVAÇÕES:
- Banco/migração: não houve.
- Configuração/parâmetro: não houve.
```
