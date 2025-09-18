#!/usr/bin/env bash

tmp_dir="/tmp/cliphist"
rm -rf "$tmp_dir"

# Check if input is from stdin or argument
if [[ -n "$1" ]]; then
    # Extract the ID from the selected line (first field before any spaces)
    cliphist_id=$(echo "$1" | cut -d' ' -f1)
    printf "%s" "$cliphist_id" | cliphist decode | wl-copy
    exit
elif [[ ! -t 0 ]]; then
    # Input from pipe/stdin - read the entire input
    input=$(cat)
    if [[ -n "$input" ]]; then
        # Extract just the ID (first field before spaces)
        cliphist_id=$(echo "$input" | cut -d' ' -f1)
        printf "%s" "$cliphist_id" | cliphist decode | wl-copy
        exit
    fi
fi

mkdir -p "$tmp_dir"

read -r -d '' prog <<EOF
/^[0-9]+\s<meta http-equiv=/ { next }
match(\$0, /^([0-9]+)\s(\[\[\s)?binary.*(jpg|jpeg|png|bmp)/, grp) {
    system("echo " grp[1] "\\\\\\t | cliphist decode >$tmp_dir/"grp[1]"."grp[3])
    print \$0"\0icon\x1f$tmp_dir/"grp[1]"."grp[3]
    next
}
1
EOF

cliphist list | gawk "$prog"
