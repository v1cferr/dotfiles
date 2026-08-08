# Histórico

O que foi feito, e — mais importante — **por quê**, o que foi tentado e
**recusado**, e qual armadilha custou caro. É o arquivo que responde "por que
isto está assim?" seis meses depois.

Um arquivo por mês. Entrada nova vai no mês corrente, no topo (ordem
cronológica reversa dentro de cada arquivo).

| Mês | Entradas |
| --- | --- |
| [2026-08](2026-08.md) | 35 |
| [2026-07](2026-07.md) | 63 |

## Como as datas foram atribuídas

O corte por mês aconteceu em 08/08/2026, quando o histórico já tinha 98
entradas e só 35 traziam data explícita. As outras foram datadas em cascata:

1. `dd/mm/aaaa` no texto — a data que o autor afirmou
2. `dd/mm` sem ano, ou `mes/aaaa` — o repo só tem 2026
3. **Arqueologia do git**: `git log -S "<título>" --reverse` acha o commit que
   introduziu a entrada
4. Sem nenhum sinal → julho, o mês de abertura do repo

⚠️ **9 entradas de julho estão lá por inferência do passo 4.** Não têm data no
texto e o `git log -S` não achou o commit — provavelmente foram reescritas depois
de criadas, então a string atual nunca existiu num commit antigo. Julho é palpite
conservador, não fato.

Uma pegadinha que atrapalhou a arqueologia e vale registrar: `git log` restrito a
`docs/` mostrava tudo nascendo em 04/08, porque foi quando o arquivo se mudou pra
essa pasta. A história real começa em **18/07** e só aparece com `--follow`, ou
buscando `-S` sem restringir caminho.

## Convenção para entrada nova

Entrada nova **deve** trazer a data no título — `(08/08/2026)`. Isso deixa de ser
estilo e passa a ser o que garante que ela caia no arquivo certo sem arqueologia.
