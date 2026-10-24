# disk-growth.awk: the size delta of each path between the LAST TWO dates seen in the input.
#
# Input: trend.tsv rows, `DATE<TAB>MiB<TAB>PATH`. Dates count in order of first appearance, so a
# caller can append live `du` rows under any label (disk-watch uses "now") to compare the present
# against the last snapshot. Output: `+12.3 GiB  PATH`, unsorted, only beyond +/- `min` GiB.
# Shared by disk-report and disk-watch so the two never disagree on what "grew" means.
BEGIN { FS = "\t"; if (min == "") min = 0.5 }
{ v[$3 SUBSEP $1] = $2; p[$3] = 1; if (!($1 in ds)) { ds[$1] = 1; o[++n] = $1 } }
END {
  if (n < 2) exit
  prev = o[n - 1]; cur = o[n]
  for (path in p) {
    a = v[path SUBSEP cur]; b = v[path SUBSEP prev]
    if (a == "" || b == "") continue
    d = (a - b) / 1024
    if (d > min || d < -min) printf "%+8.1f GiB  %s\n", d, path
  }
}
