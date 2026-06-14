user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("devtools.chrome.enabled", true);
user_pref("devtools.debugger.remote-enabled", true);
user_pref("browser.content.full-zoom", 0.78);

// === Aceleração de vídeo por hardware (VA-API -> NVDEC, NVIDIA/Wayland) ===
// Complementa as env vars do Hyprland (LIBVA_DRIVER_NAME=nvidia, NVD_BACKEND=
// direct, MOZ_DISABLE_RDD_SANDBOX=1) + pacote libva-nvidia-driver.
// Sem estas prefs o Zen decodifica vídeo na CPU. Se algum vídeo travar,
// comente media.ffmpeg.vaapi.enabled e reinicie o Zen.
user_pref("media.ffmpeg.vaapi.enabled", true);            // interruptor principal
user_pref("media.hardware-video-decoding.enabled", true); // default true, explícito
user_pref("media.rdd-ffmpeg.enabled", true);              // decode no processo RDD isolado
// O Firefox/Zen BLOCKLISTA DMABUF + decode por HW no NVIDIA proprietário
// (about:support mostrava "Force disabled by gfxInfo" e tudo SWDEC). Estas
// duas furam a blocklist — sem elas as prefs acima não têm efeito no NVIDIA.
user_pref("widget.dmabuf.force-enabled", true);               // DMABUF (pré-requisito do VAAPI)
user_pref("media.hardware-video-decoding.force-enabled", true); // ignora a blocklist do gfxInfo
