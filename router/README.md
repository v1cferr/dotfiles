# Roteador — Cudy WR3000 (OpenWrt)

Espelho **somente-leitura** da config do roteador. Gerado por `router-sync`
(`system/net/router.nix`), nunca editado à mão.

## Por que isto existe

O roteador é a peça de infraestrutura que o Nix não alcança: 6 MB de flash e
128 MB de RAM põem NixOS fora de escala. Até 08/08/2026 as ~750 linhas de UCI
viviam só no aparelho — sem revisão, sem histórico, e sem ninguém saber quando
mudavam. Isto não torna o roteador declarativo; torna a config **visível** e o
drift **detectável**, que era o que faltava.

## Uso

```sh
router-sync diff   # compara aparelho vs repo; sai 1 se divergir
router-sync pull   # traz o estado do aparelho pro repo
```

Depois de mexer em qualquer coisa pelo LuCI ou por `uci set`, rode `pull` e
commite. O `diff` é o que impede este diretório de virar uma cópia que já foi
verdade.

## O que NÃO está aqui

**Segredos.** Os sete valores de credencial saem redigidos (regra 12): a chave
privada do WireGuard, a senha do PPPoE, as duas senhas de WiFi, o login do LuCI,
a senha da API do adblock e a do etherwake. A redação é *fail-safe* — redige por
default tudo que o nome sugere ser credencial e só libera o que reconhece como
público (`public_key`) ou como caminho de arquivo.

**Push.** `router-sync` não escreve no roteador, de propósito. Aplicar UCI por SSH
exige commit-confirm — aplica, agenda rollback, confirma só se ainda houver
acesso — senão uma linha errada de rede tranca você fora e a saída é modo failsafe
com acesso físico. A decisão sobre a ferramenta de push está aberta em
`docs/pendencias.md`.

**O que não é UCI.** `authorized_keys`, `/etc/sudoers.d/`, `~/bin/owfetch` e o
`/etc/profile.d/99-owfetch.sh` vivem fora do UCI e continuam sendo passos manuais,
documentados na mesma entrada do TODO.

## Sobrevivência a upgrade

Medido no `keep.d` do aparelho em 08/08/2026 (38 entradas) — o `sysupgrade` já
preserva `/etc/config/` inteiro, `/etc/profile.d/`, `/etc/dropbear/`,
passwd/shadow/group **e `/etc/sudoers.d/`**.

Ficam de fora e precisam entrar no `/etc/sysupgrade.conf` do roteador:

- `/home/v1cferr/` — onde vivem a chave SSH e o `~/bin/owfetch`
- `/etc/sysupgrade.conf` — **ele mesmo**. O `list_static_conffiles` lê os caminhos
  listados dentro dele mas não o inclui, então sem essa linha o 1º upgrade
  preserva o que você pediu e o 2º perde tudo.
