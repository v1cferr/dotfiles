# docs

Era um arquivo só (`ANOTACOES.md`, 1949 linhas). Virou seis, porque um god file
esconde: com 98 entradas fechadas misturadas com 15 abertas, achar o que fazer
hoje exigia rolar por seis meses de história.

O corte é por **função**, não por tema — o que se lê todo dia (regras), o que se
age (pendências) e o que se consulta (histórico) têm ritmos diferentes.

| Arquivo | O que é | Quando se lê |
| --- | --- | --- |
| [regras.md](regras.md) | As 15 regras do repo | Antes de decidir qualquer coisa |
| [pendencias.md](pendencias.md) | O que está aberto | Ao escolher no que trabalhar |
| [historico.md](historico.md) | O que foi feito e por quê | "Por que isto está assim?" |
| [ideias.md](ideias.md) | Considerado, ainda não decidido | Ao planejar |
| [arch-legado.md](arch-legado.md) | Capítulo encerrado + como abrir o acervo | Raramente |
| [guias/](guias/) | Passo a passo de hardware/setup | Ao reinstalar |
| [testes/](testes/) | Protocolos de teste reutilizáveis | Ao validar mudança |

## Convenções

**A numeração das regras é API.** O código referencia "regra 11", "regra 14" em
mais de setenta comentários. Renumerar quebraria todos em silêncio: regra nova
entra no fim, regra morta vira tachado.

**Entrada boa explica o PORQUÊ e a armadilha**, não o o-quê — o código já diz o
o-quê. As entradas mais valiosas aqui são as que registram algo TENTADO E
RECUSADO, porque impedem a próxima pessoa (ou você em seis meses) de repetir.

**Item concluído migra** de `pendencias.md` para `historico.md`. Um arquivo só
cresce, o outro encolhe.
