#!/usr/bin/env bash
# P0-10 dry run, run ON the build VM (detaches itself). Usage: dryrun-p0-10.sh [jobs]
# State and logs go to /srv/pini/out/p0-10/; see dryrun-status.sh.
set -euo pipefail
JOBS="${1:-2}"; V=v26.11.1
SRC=/srv/pini/src/p0-10; OUT=/srv/pini/out/p0-10; TAG=pini-builder:p0-10
NAME="pini-p0-10-j$JOBS"; LOG="$OUT/build-j$JOBS.log"; ST="$OUT/status-j$JOBS"
mkdir -p "$OUT"

if [ "${PINI_DETACHED:-}" != 1 ]; then
  rm -f "$ST" "$OUT/exit-j$JOBS" "$OUT/memory.peak-j$JOBS"
  PINI_DETACHED=1 setsid nohup "$0" "$JOBS" >>"$LOG" 2>&1 < /dev/null &
  echo "started detached (j$JOBS); log: $LOG"; exit 0
fi

st() { echo "$1=$2" >> "$ST"; }
st started "$(date -u +%FT%TZ)"; st jobs "$JOBS"; st phase image

t0=$(date +%s)
docker build -t "$TAG" -f "$(dirname "$0")/Dockerfile.builder" "$OUT"
st image_seconds "$(( $(date +%s) - t0 ))"
st image_id "$(docker image inspect --format '{{.Id}}' "$TAG")"
st image_size_bytes "$(docker image inspect --format '{{.Size}}' "$TAG")"

cat > "$OUT/inner-j$JOBS.sh" <<INNER
set -euo pipefail
set +u; source scl_source enable gcc-toolset-14; set -u
cd /work && rm -rf node-$V && tar xf /src/node-$V.tar.xz && cd node-$V
{ clang --version | head -1; gcc --version | head -1; python3 --version; rustc --version; cargo --version; ld.lld --version; rpm -q glibc; } > /work/toolchain.txt 2>&1
s=\$(date +%s)
python3 ./configure --v8-enable-temporal-support
echo "configure_seconds=\$(( \$(date +%s) - s ))" > /work/timing.txt
s=\$(date +%s)
make -j$JOBS
echo "make_seconds=\$(( \$(date +%s) - s ))" >> /work/timing.txt
out/Release/node -p 'JSON.stringify(process.versions)' > /work/versions.json
out/Release/node -p 'JSON.stringify(process.config.variables)' > /work/config-variables.json
ls -l out/Release/node >> /work/timing.txt
du -sk /work/node-$V | sed 's/^/work_kb=/' >> /work/timing.txt
INNER

st phase build; st build_started "$(date -u +%FT%TZ)"
mkdir -p "$OUT/work-j$JOBS"
docker rm -f "$NAME" >/dev/null 2>&1 || true
CID=$(docker run -d --name "$NAME" --memory 10g --memory-swap 10g --cpus 2 \
  -v "$SRC":/src:ro -v "$OUT/work-j$JOBS":/work -v "$OUT/inner-j$JOBS.sh":/inner.sh:ro \
  "$TAG" bash /inner.sh)
st container_id "$CID"
# memory.peak vanishes with the cgroup: keep sampling (it is monotonic, last value = peak)
( while docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null | grep -q true; do
    cat /sys/fs/cgroup/system.slice/docker-"$CID".scope/memory.peak > "$OUT/memory.peak-j$JOBS" 2>/dev/null || true
    sleep 5; done ) &
RC=$(docker wait "$NAME"); wait
docker logs "$NAME" >> "$LOG" 2>&1 || true
echo "$RC" > "$OUT/exit-j$JOBS"
st build_ended "$(date -u +%FT%TZ)"; st exit_code "$RC"; st phase done
