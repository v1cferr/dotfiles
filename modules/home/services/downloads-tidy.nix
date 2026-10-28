# DOWNLOADS TIDY: the root of ~/Downloads is an inbox, sorted into type folders every 30 min.
# The inbox model, the buckets and the trash window: docs/notes/boot-and-storage/downloads-tidy.md
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
    findutils
    trash-cli
    writeShellApplication
    ;

  cfg = config.my.downloads;

  # One `case` arm per bucket, generated from the attrset so a new extension is 1 word in Nix.
  bucketArms = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      bucket: exts:
      "${lib.concatMapStringsSep "|" (e: "*.${e}") exts}) echo ${lib.escapeShellArg bucket} ;;"
    ) cfg.buckets
  );

  trashArgs = lib.escapeShellArgs cfg.trashBuckets;

  downloadsTidy = writeShellApplication {
    name = "downloads-tidy";
    runtimeInputs = [
      coreutils
      findutils
      trash-cli
    ];
    text = ''
      dry=0
      [ "''${1:-}" = "--dry-run" ] && dry=1
      dir=${lib.escapeShellArg cfg.dir}
      [ -d "$dir" ] || exit 0

      bucket_of() {
        case "''${1,,}" in
          ${bucketArms}
          *) echo Other ;;
        esac
      }

      # Never overwrite: a clash becomes "name (2).ext", "name (3).ext"...
      free_target() {
        local dest="$1" name="$2" stem ext n=2 target
        target="$dest/$name"
        if [[ "$name" == *.* ]]; then stem="''${name%.*}"; ext=".''${name##*.}"; else stem="$name"; ext=""; fi
        while [ -e "$target" ]; do
          target="$dest/$stem ($n)$ext"
          n=$((n + 1))
        done
        printf '%s\n' "$target"
      }

      # Phase 1: sort. Only loose files that settled: both -mmin and -cmin, because a browser may
      # stamp the server's old mtime on a file that landed a second ago.
      find "$dir" -maxdepth 1 -type f \
        -mmin +${toString cfg.settleMinutes} -cmin +${toString cfg.settleMinutes} -print0 |
        while IFS= read -r -d "" f; do
          name="''${f##*/}"
          case "''${name,,}" in
            .* | *.part | *.crdownload | *.download | *.tmp) continue ;; # hidden or still downloading
          esac
          bucket="$(bucket_of "$name")"
          if [ "$dry" = 1 ]; then
            echo "would move: $name -> $bucket/"
            continue
          fi
          mkdir -p "$dir/$bucket"
          target="$(free_target "$dir/$bucket" "$name")"
          mv -n -- "$f" "$target" && echo "moved: $name -> $bucket/''${target##*/}"
        done

      # Phase 2: disposable buckets go to the trash (never rm). -ctime and not -mtime: the move
      # above resets ctime, so the clock counts from when the file was SORTED, not from the
      # server's timestamp.
      for b in ${trashArgs}; do
        b="$dir/$b"
        [ -d "$b" ] || continue
        find "$b" -type f -ctime +${toString cfg.trashAfterDays} -print0 |
          while IFS= read -r -d "" f; do
            if [ "$dry" = 1 ]; then
              echo "would trash: ''${f#"$dir"/}"
            else
              trash-put -- "$f" && echo "trashed: ''${f#"$dir"/}"
            fi
          done
      done
    '';
  };
in
{
  options.my.downloads = {
    dir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Downloads";
      description = "The inbox: only the files loose at its root are sorted.";
    };
    settleMinutes = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Minutes a file must sit untouched before it is sorted (protects running downloads).";
    };
    trashAfterDays = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Days a file sits in a disposable bucket before it goes to the trash.";
    };
    trashBuckets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "Installers"
        "Disk-images"
      ];
      description = "Buckets whose content is disposable (it can be downloaded again).";
    };
    buckets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      description = "Folder name to lowercase extensions; anything unmatched goes to Other/.";
    };
  };

  config = {
    my.downloads.buckets = {
      Archives = [
        "zip"
        "rar"
        "7z"
        "tar"
        "gz"
        "xz"
        "zst"
        "bz2"
      ];
      Audio = [
        "mp3"
        "opus"
        "flac"
        "ogg"
        "wav"
        "m4a"
      ];
      Code = [
        "json"
        "xml"
        "html"
        "yml"
        "yaml"
        "toml"
        "sh"
        "py"
        "nix"
      ];
      # the checksum and signature travel with the image they verify
      Disk-images = [
        "iso"
        "img"
        "qcow2"
        "iso.sha256"
        "iso.sig"
      ];
      Documents = [
        "pdf"
        "doc"
        "docx"
        "odt"
        "rtf"
        "txt"
        "md"
        "epub"
      ];
      Images = [
        "png"
        "jpg"
        "jpeg"
        "webp"
        "gif"
        "svg"
        "heic"
        "avif"
      ];
      Installers = [
        "deb"
        "rpm"
        "apk"
        "appimage"
        "exe"
        "msi"
      ];
      Spreadsheets = [
        "xls"
        "xlsx"
        "ods"
        "csv"
      ];
      Video = [
        "mp4"
        "mkv"
        "webm"
        "mov"
        "avi"
      ];
    };

    home.packages = [ downloadsTidy ];

    systemd.user.services.downloads-tidy = {
      Unit.Description = "Sorts the loose files in ~/Downloads into type folders";
      Service = {
        Type = "oneshot";
        ExecStart = "${downloadsTidy}/bin/downloads-tidy";
        # The script's lines go out as notice, systemd's own Starting/Finished (info) are cut:
        # 48 runs a day would otherwise drown the journal (the disk-hygiene lesson).
        SyslogLevel = "notice";
        LogLevelMax = "notice";
      };
    };

    systemd.user.timers.downloads-tidy = {
      Unit.Description = "Sort ~/Downloads every 30 min";
      Timer = {
        OnCalendar = "*:0/30";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
