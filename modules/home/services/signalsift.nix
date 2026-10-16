# SIGNALSIFT: my content intelligence daemon (feeds, transcripts, local LLM) as a user service.
# Why a user service, the GPU-only rule and the first run: docs/notes/services/signalsift.md
{ inputs, pkgs, ... }:

let
  inherit (pkgs) fetchurl;

  # Pinned by hash (rule 13): the exact files benchmarked in the SignalSift repo's docs/benchmarks/.
  hf =
    repo: file: hash:
    fetchurl {
      url = "https://huggingface.co/${repo}/resolve/main/${file}";
      inherit hash;
    };
  whisper =
    hf "ggerganov/whisper.cpp" "ggml-large-v3-turbo-q5_0.bin"
      "sha256-OUIhcJzVrR9AxG5gMcphvOiJMebgiMGIKUxtWlX/p+I=";
  vad =
    hf "ggml-org/whisper-vad" "ggml-silero-v5.1.2.bin"
      "sha256-KZQNmNQrkfvQXOSJ8+z3xy8KQvAn5IdZGaKPtMBOos8=";
  llm =
    hf "google/gemma-4-E4B-it-qat-q4_0-gguf" "gemma-4-E4B_q4_0-it.gguf"
      "sha256-Z2w1Bw222+Uvk+nIZO4Puk7d6pS5yHXZyxDa/0U/uu4=";
in
{
  imports = [ inputs.signal-sift.homeManagerModules.default ];

  services.signalsift = {
    enable = true;
    settings = {
      # require_gpu is already the default; stated because it is the rule I care about here.
      runtime.require_gpu = true;
      asr.model = "${whisper}";
      asr.vad_model = "${vad}";
      analysis.model = "${llm}";
      analysis.interests_file = "${./signalsift-interests.toml}";
    };
  };
}
