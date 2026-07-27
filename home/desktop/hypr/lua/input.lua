-- ── Input (teclado/mouse) ───────────────────────────────────────────────────
-- Portado do input.conf do Arch. Teclado ABNT2; mouse sem aceleração (flat) e
-- numlock ligado (desktop). Sem touchpad real, mas deixado configurado.
hl.config({
  input = {
    kb_layout = "br",
    kb_variant = "abnt2",
    numlock_by_default = true, -- numpad ligado no boot (desktop)
    follow_mouse = 1,          -- o mouse sempre muda o foco
    sensitivity = 0,           -- sem modificação (-1.0..1.0)
    accel_profile = "flat",    -- sem aceleração (preciso p/ jogos/trabalho)
    natural_scroll = false,    -- scroll tradicional (não invertido)
    scroll_factor = 1.0,
    touchpad = {
      natural_scroll = false,
    },
  },
})

-- Teclado VIRTUAL do Sunshine (acesso remoto Moonlight) = layout US, por-dispositivo.
-- Motivo: o Moonlight NÃO envia a tecla "/ ?" do ABNT2 (bug #1789 — é a tecla
-- internacional que teclados US não têm, então o evento morre no cliente). No layout
-- US o "/" cai numa tecla padrão que o Moonlight envia normalmente. Só afeta o STREAM;
-- o teclado FÍSICO de casa continua ABNT2 (config global acima). Variante us,intl dá
-- acentos/ç via dead-keys, se um dia quiser (kb_variant = "intl").
hl.device({ name = "keyboard-passthrough", kb_layout = "us" })
