# Teste: Moonlight direto, sem VPN, da UFSCar

**Onde:** UFSCar, no notebook da FAI, **sem WireGuard e sem nenhuma VPN ativa**.
**Por quê:** o caminho direto (`docs/history/2026/08-august.md` não cobre — foi
aberto em 10/08/2026) troca o túnel por port-forward restrito. O TCP está provado; o
UDP não. Este protocolo separa "não passa UDP" de "problema de vídeo", que produzem
sintomas quase idênticos.

⚠️ **A VPN tem que estar DESLIGADA.** Com o túnel de pé o teste mente: o Moonlight
acha o host por `10.10.10.1` e você mede o caminho antigo achando que mediu o novo.
É a variante 2 da armadilha de método registrada em 08/08 — teste que parece externo
e não é.

## 0. Pré-requisitos

- Host: `system/services/sunshine.nix` aplicado (`nixos-rebuild switch`).
- Roteador: `scripts/router-moonlight-forward.sh` executado.

## 1. O `src_ip` está segurando? (teste de SEGURANÇA, não de alcance)

⚠️ **Este passo tem que FALHAR para passar.** As redirects são restritas aos blocos da
UFSCar, então um ponto externo qualquer precisa ser recusado. Se ele conectar, o
`src_ip` não está aplicado e o Sunshine está aberto pro planeta.

⚠️ E de dentro da LAN o teste não vale nada: a operadora faz hairpin e a porta
"abre" sempre. Só de fora.

```sh
curl -s "https://check-host.net/check-tcp?host=177.52.84.188%3A47984&max_nodes=3" \
  -H "Accept: application/json"
# pega o request_id, espera ~10s, e:
curl -s "https://check-host.net/check-result/<request_id>" -H "Accept: application/json"
```

- `{"error": "Connection refused"}` em TODOS os nós → ✅ correto, o `src_ip` segura
- `{"address": "177.52.84.188", "time": …}` em qualquer nó → 🔴 **pare**: a restrição
  não pegou. Confira `uci show firewall | grep -i moonlight` no roteador

**Contra-teste que dá sentido ao acima:** rode o mesmo na **2222**, que é irrestrita.
Ela TEM que conectar (medido em 10/08/2026: Áustria, Canadá e Irã, todos OK). Sem
esse controle, "refused" nas duas seria indistinguível de "o link caiu" — e você
teria lido uma queda de internet como sucesso de segurança.

**Terceiro contra-teste:** a **47990**. Refused, sempre, de qualquer lugar — é o
painel admin e não está encaminhado. Ver o aviso do `origin_web_ui_allowed` em
`sunshine.nix`.

Consequência do desenho: **este método não consegue confirmar que a porta abriu para
a UFSCar** — só o passo 2, de dentro dela, faz isso.

## 2. Chega da UFSCar? (no notebook, sem VPN)

```sh
nc -vz ssh.v1cferr.dev 47984 47989 48010
```

Se o TCP falhar aqui e tiver passado no passo 1, o bloqueio é da rede da UFSCar, não
sua. Registrado em 08/08: **a rede da FAI descarta o SYN-ACK** — o SYN chega em casa,
o host responde, e o ACK final nunca volta. Se o notebook estiver no segmento da FAI
(`200.136.192.0/21`) em vez do campus (`200.133.224.0/20`), é o caso esperado, e a
resposta é usar o túnel.

## 2b. ⚠️ Parear um cliente NOVO não funciona por este caminho

O notebook da FAI (`"fai pc"`, pareado em 27/07/2026) entra direto: cliente já pareado
usa o certificado que tem, e isso é 47984 pura. **Cliente novo é outra história** — o
PIN se digita no web UI, que é a **47990**, e ela não é encaminhada de propósito.

Não force a 47990 para o mundo. As saídas:

1. **Parear pelo túnel WireGuard**, uma vez, e depois usar o caminho direto para
   sempre. É a mais simples e não mexe em nada.
2. Túnel SSH: `ssh -L 47990:localhost:47990 v1cferr@ssh.v1cferr.dev -p 2222` e abrir
   `https://localhost:47990`.
   ⚠️ **Não verificado, e há motivo concreto para desconfiar:** o
   `csrf_allowed_origins` do `sunshine.nix` lista só `https://192.168.1.10:47990`, e
   por esse túnel o browser manda `Origin: https://localhost:47990`. Enviar o PIN é
   POST, então o CSRF vale. Se der erro ao salvar, é isto — e o conserto é somar essa
   origem à opção, não abrir a porta.

## 3. O UDP — a pergunta que este teste existe pra responder

Não há como testar UDP com `nc -z` de forma conclusiva (sem resposta ≠ bloqueado).
O teste real é streamar. Parear e rodar **5 minutos**, observando:

| Sintoma | Leitura |
| --- | --- |
| Não pareia | TCP — volte ao passo 2 |
| Pareia, lista os apps, e a tela **nunca aparece** | **UDP bloqueado.** É o caso desconfiado |
| Abre e congela em segundos, sem erro de encoder no journal | **UDP bloqueado ou intermitente** |
| Abre e cai em ~4 s, repetidamente | MTU — ver `wireguard-moonlight.md` |
| Roda 5 min | ✅ funciona |

Em casa, depois: `moonlight-stats 1`.

⚠️ **"Pareia mas não streama" é o modo de falha a memorizar.** Pareamento e lista de
apps são TCP (47989/47984); vídeo, áudio e controle são UDP (47998-48000). Uma sessão
que abre e congela parece bug de captura ou de encoder — e neste caminho quase nunca
é. Antes de mexer em qualquer coisa do Sunshine, descarte o UDP.

## 4. Se o UDP estiver bloqueado

Não há conserto deste lado: quem descarta é o firewall da UFSCar. As saídas, em ordem
de preferência:

1. **Voltar ao túnel** — continua de pé, e enfia tudo dentro da 51820/UDP, que está
   PROVADO atravessar aquela rede (medido em 08/08). É o motivo de não desmontá-lo.
2. Pedir liberação à CoTI/SIn (`sin-citi@ufscar.br`) — as portas são fixas e
   documentáveis, mas o prazo é institucional.

## 5. Resultado — 10/08/2026 ✅

O caminho direto NÃO é uma rota melhor: é o mesmo caminho, sem encapsulamento (o
endpoint do WireGuard é o próprio roteador). O que ele ganha é MTU (1492 da PPPoE
contra ~1420 do túnel) e dispensar o cliente de VPN.

**O UDP passa.** Era a única incógnita e está respondida — não por inferência, mas
pelo contador de DNAT do roteador: `Moonlight-Stream-Campus → packets 3`. Esse
contador só conta o PRIMEIRO pacote de cada fluxo novo (depois o conntrack desvia do
dstnat), então 3 = exatamente os três fluxos esperados, vídeo 47998 + áudio 47999 +
controle 48000. Guardar o método: é a forma mais barata de provar fluxo UDP sem
instrumentar o cliente.

Medido de casa até `200.133.233.101`, 100 pacotes de 1 KB:

| Métrica | Valor |
| --- | --- |
| RTT médio | 35,5 ms (min 34,7 / max 38,1) |
| Perda | **0%** |
| Jitter (mdev) | 0,54 ms |
| Sessão mais longa | 21m58s, seguida de 9 min+ |
| Vazão em uso de desktop | ~3 Mbps ↑ |

Contra a medição de jul/2026 no caminho da FAI (**1,67% de perda, RTT 20 → 312 ms**),
é outro mundo. ⚠️ Mas não é comparação limpa: segmento de origem diferente (campus vs
FAI) e ICMP é despriorizado por switch. Vale como indício forte, não como prova sobre
o fluxo de vídeo — para isso, o overlay do Moonlight (`Ctrl+Alt+Shift+S`).

**Latência: é ruído, como previsto.** Os 35 ms são o RTT do caminho físico, que o
túnel percorria igual. Não houve ganho de rota porque não havia rota a ganhar.

A rota, com os donos identificados por RDAP — quatro sistemas autônomos, nenhum deles
um servidor intermediário (todos encaminham pacote, nenhum termina a conexão):

```text
roteador → Algar Telecom (AS16735) → IX.br/NIC.br (AS26162)
         → RNP (AS1916) → UFSCar (AS52888) → notebook
```

O IX.br e a RNP não são removíveis: a internet da UFSCar vem da RNP.

### O que a sessão real revelou, e não estava previsto aqui

- **`ping_timeout = 20000` absorveu um buraco de 18,9 s** às 11:47 sem derrubar a
  sessão. A prova é que o guard do hypridle não ciclou (um único `Stopped` às 11:25,
  nenhum `Started` às 11:47) — o `undo` do prep-cmd nunca rodou. Método reaproveitável:
  o guard é um detector de fim-de-sessão mais confiável que a linha
  `CLIENT DISCONNECTED`, que sai tanto em queda real quanto em reconexão absorvida.
  ⚠️ As duas quedas do dia (18,9 s e 104 s) foram o DONO reconectando, confirmado por
  ele. Não são indício de rota instável — todos os testes deram 0% de perda.
- **HEVC: negocia, mas não serve neste cliente.** Ligado às 14:43 (`hevc_vaapi`,
  Rec. 709) e desligado pelo dono às 14:57 por estar "muito bugado" na prática.
  H.264 é a escolha final para esta máquina, e é DELIBERADA — não é o default que
  ninguém revisou.
  ⚠️ Isso desmente a nota de 03/08 do `sunshine.nix` PARA ESTE CLIENTE, e é o registro
  que impede a próxima pessoa de repetir: lá está escrito que ligar HEVC/AV1 "vale mais
  que qualquer ajuste do host". Vale — onde o decode presta. Aqui negociou limpo no
  journal e entregou imagem ruim, que é o pior caso possível de diagnosticar, porque do
  lado do host TUDO parece certo.
- `Video encryption enabled` nas duas sessões — o modo WAN entrou sozinho, sem
  configurar nada.
