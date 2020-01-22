#env \
#  CLEAN=true \
#  ABSROOTDIR=$PWD \
#  ABSOUTDIR=$PWD/output \
#  ~/github.com/sourcegraph/lsif-cpp/generate-csv "make"

node \
  ~/github.com/sourcegraph/lsif-cpp/out/main.js \
  --csvFileGlob="output/*.csv" \
  --root=. \
  --out dump.lsif
