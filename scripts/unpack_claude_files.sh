#!/usr/bin/env bash
set -euo pipefail
INPUT="${1:-out.txt}"
awk '
  /^<<<FILE: /{ fname=substr($0,10,length($0)-10); sub(/>>>$/,"",fname); getting=1;
    n=split(fname,arr,"/"); path=""; for(i=1;i<n;i++){ path=path arr[i] "/" } if(path!=""){ system("mkdir -p \""path"\"") }
    out=fname; next }
  /^<<<END FILE>>>/{ getting=0; out=""; next }
  getting{ print $0 >> out }
' "$INPUT"
echo "[OK] Files unpacked from $INPUT"