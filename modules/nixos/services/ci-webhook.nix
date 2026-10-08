# CI WEBHOOK: the FAI GitLab's Pipeline Hook, via the tunnel (`ci` ingress), so the band sees the
# FAI pipelines off the VPN; only the receiver, the logic is in dash/scripts/: docs/notes/desktop/dash.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    coreutils
    jq
    writeShellApplication
    ;

  # Self-activating with its secret, like the tunnel: the toggle alone keeps it inert until
  # sync-secrets has brought the token, so a half-done setup never listens.
  enabled =
    config.my.services.ci-webhook && builtins.hasAttr "fai_gitlab_webhook_token" config.sops.secrets;

  store = writeShellApplication {
    name = "ci-webhook-store";
    runtimeInputs = [
      jq
      coreutils
    ];
    text = builtins.readFile ../../home/desktop/quickshell/dash/scripts/ci-webhook-store.sh;
  };
in
{
  config = lib.mkIf enabled {
    services.webhook = {
      enable = true;
      ip = "127.0.0.1"; # loopback only: the tunnel is the one way in, never the LAN
      port = 9123;
      # The token is read at RUNTIME through `credential` (LoadCredential below), so it never
      # reaches the store. The non-empty rule matters: `credential` yields "" when the file is
      # missing, and an empty header would otherwise match it.
      hooksTemplated.gitlab = builtins.toJSON {
        id = "gitlab";
        execute-command = "${store}/bin/ci-webhook-store";
        pass-arguments-to-command = [ { source = "entire-payload"; } ];
        response-message = "stored";
        trigger-rule-mismatch-http-response-code = 403;
        trigger-rule.and = [
          {
            match = {
              type = "regex";
              regex = ".+";
              parameter = {
                source = "header";
                name = "X-Gitlab-Token";
              };
            };
          }
          {
            match = {
              type = "value";
              # Backticks, not quotes: toJSON escapes a quote to \" and Go's template parser chokes.
              value = "{{ credential `gitlab-token` | js }}";
              parameter = {
                source = "header";
                name = "X-Gitlab-Token";
              };
            };
          }
        ];
      };
    };

    systemd.services.webhook.serviceConfig = {
      LoadCredential = "gitlab-token:${config.sops.secrets.fai_gitlab_webhook_token.path}";
      # 0755 so glance-feed, running as me, reads what the hook wrote.
      StateDirectory = "ci-webhook";
      StateDirectoryMode = "0755";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };
}
