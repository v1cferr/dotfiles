# docs

Era um arquivo só (`ANOTACOES.md`, 1949 linhas). Virou seis, porque um god file
esconde: com 98 entradas fechadas misturadas com 15 abertas, achar o que fazer
hoje exigia rolar por seis meses de história.

O corte é por **função**, não por tema — o que se lê todo dia (regras), o que se
age (pendências) e o que se consulta (histórico) têm ritmos diferentes.

| Arquivo | O que é | Quando se lê |
| --- | --- | --- |
| [rules.md](rules.md) | As 16 regras do repo | Antes de decidir qualquer coisa |
| [open-items.md](open-items.md) | O que está aberto | Ao escolher no que trabalhar |
| [history/](history/) | O que foi feito e por quê — pasta por ano, arquivo por mês | "Por que isto está assim?" |
| [ideas.md](ideas.md) | Considerado, ainda não decidido | Ao planejar |
| [arch-legacy.md](arch-legacy.md) | Capítulo encerrado + como abrir o acervo | Raramente |
| [guias/](guides/) | Passo a passo do que o Nix não alcança (BIOS, Secure Boot, roteador, Windows) | Ao reinstalar ou mexer fora do repo |
| [testes/](tests/) | Protocolos de teste reutilizáveis | Ao validar mudança |

## Convenções

**A numeração das regras é API.** O código referencia "regra 11", "regra 14" em
mais de setenta comentários. Renumerar quebraria todos em silêncio: regra nova
entra no fim, regra morta vira tachado.

**Entrada boa explica o PORQUÊ e a armadilha**, não o o-quê — o código já diz o
o-quê. As entradas mais valiosas aqui são as que registram algo TENTADO E
RECUSADO, porque impedem a próxima pessoa (ou você em seis meses) de repetir.

**Item concluído migra** de `open-items.md` para `history/<mês>.md`. Um arquivo só
cresce, o outro encolhe.
