SERVER=8.138.247.4 LABEL=tx TCP_P=4 UDP_BW=20M REPEAT=2 PING_COUNT=20 MTR_CYCLES=20 IPERF_TIME=25 OMIT=3 bash <<'EOF'
set -u

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "缺少命令: $1"; exit 1; }
}

need_cmd iperf3
need_cmd python3
need_cmd ping

PORT="${PORT:-5201}"

echo "=== cloud-netcheck 开始 ==="
echo "label=$LABEL  server=$SERVER  port=$PORT"
echo "tcp_p=$TCP_P  udp_bw=$UDP_BW  repeat=$REPEAT"
echo "ping_count=$PING_COUNT  mtr_cycles=$MTR_CYCLES  iperf_time=$IPERF_TIME  omit=$OMIT"
echo "临时文件自动清理，无需手动找日志。"
echo

echo "[1/6] Ping（约 ${PING_COUNT}s）"
LC_ALL=C ping -q -n -c "$PING_COUNT" "$SERVER" | tee "$TMP/ping.txt" || true
echo

echo "[2/6] MTR（约 ${MTR_CYCLES}s）"
if command -v mtr >/dev/null 2>&1; then
  LC_ALL=C mtr -n -r -w -c "$MTR_CYCLES" "$SERVER" | tee "$TMP/mtr.txt" || true
else
  echo "mtr 未安装，跳过" | tee "$TMP/mtr.txt"
fi
echo

run_iperf() {
  local name="$1"
  shift
  local i fn err pid rc sec

  for i in $(seq 1 "$REPEAT"); do
    case "$name" in
      tcp_fwd)
        echo "[3/6] TCP 正向 第 $i/$REPEAT 次：客户端出网 / 服务端入网（约 ${IPERF_TIME}s）"
        ;;
      tcp_rev)
        echo "[4/6] TCP 反向 第 $i/$REPEAT 次：客户端入网 / 服务端出网（约 ${IPERF_TIME}s）"
        ;;
      udp_fwd)
        echo "[5/6] UDP 正向 第 $i/$REPEAT 次：客户端出网 / 服务端入网（约 ${IPERF_TIME}s, 目标 ${UDP_BW}）"
        ;;
      udp_rev)
        echo "[6/6] UDP 反向 第 $i/$REPEAT 次：客户端入网 / 服务端出网（约 ${IPERF_TIME}s, 目标 ${UDP_BW}）"
        ;;
    esac

    fn="$TMP/${name}.${i}.json"
    err="$TMP/${name}.${i}.err"

    (LC_ALL=C iperf3 "$@" -J >"$fn" 2>"$err") &
    pid=$!
    sec=0
    while kill -0 "$pid" 2>/dev/null; do
      sec=$((sec+1))
      printf "\r    运行中... %2ds" "$sec"
      sleep 1
    done
    wait "$pid"
    rc=$?
    printf "\r"

    if [ "$rc" -eq 0 ]; then
      python3 - "$fn" "$name" <<'PY'
import sys, json
fn, name = sys.argv[1], sys.argv[2]
j = json.load(open(fn))
end = j.get("end", {})

if name.startswith("tcp"):
    recv = end.get("sum_received") or end.get("sum") or {}
    sent = end.get("sum_sent") or {}
    bps = recv.get("bits_per_second")
    retr = sent.get("retransmits")
    bps_s = f"{bps/1e6:.2f}" if isinstance(bps, (int, float)) else "N/A"
    retr_s = str(retr) if retr is not None else "N/A"
    print(f"    完成：吞吐={bps_s} Mbps, Retr={retr_s}")
else:
    s = end.get("sum") or end.get("sum_received") or end.get("sum_sent") or {}
    bps = s.get("bits_per_second")
    jit = s.get("jitter_ms")
    lp = s.get("lost_percent")
    bps_s = f"{bps/1e6:.2f}" if isinstance(bps, (int, float)) else "N/A"
    jit_s = f"{float(jit):.3f}" if jit is not None else "N/A"
    lp_s = f"{float(lp):.3f}" if lp is not None else "N/A"
    print(f"    完成：吞吐={bps_s} Mbps, jitter={jit_s} ms, 丢包={lp_s}%")
PY
    else
      echo "    失败：rc=$rc"
      [ -s "$err" ] && sed 's/^/    /' "$err"
    fi

    echo
    sleep 1
  done
}

run_iperf tcp_fwd -c "$SERVER" -p "$PORT" -P "$TCP_P" -t "$IPERF_TIME" -O "$OMIT"
run_iperf tcp_rev -c "$SERVER" -p "$PORT" -R -P "$TCP_P" -t "$IPERF_TIME" -O "$OMIT"
run_iperf udp_fwd -c "$SERVER" -p "$PORT" -u -b "$UDP_BW" -t "$IPERF_TIME"
run_iperf udp_rev -c "$SERVER" -p "$PORT" -u -R -b "$UDP_BW" -t "$IPERF_TIME"

python3 - "$TMP" "$LABEL" "$SERVER" "$TCP_P" "$UDP_BW" "$REPEAT" <<'PY'
import sys, os, re, json, glob, statistics

tmp, label, server, tcp_p, udp_bw, repeat = sys.argv[1:]

def med(vals):
    return statistics.median(vals) if vals else None

def fmt(v, nd=2):
    return "N/A" if v is None else f"{v:.{nd}f}"

def fmt_list(vals, nd=2):
    return "[" + ", ".join(f"{v:.{nd}f}" for v in vals) + "]" if vals else "[]"

def load_jsons(prefix):
    arr = []
    for fn in sorted(glob.glob(os.path.join(tmp, f"{prefix}.*.json"))):
        try:
            with open(fn, "r", encoding="utf-8") as f:
                arr.append(json.load(f))
        except Exception:
            pass
    return arr

def parse_tcp(js):
    end = js.get("end", {})
    recv = end.get("sum_received") or end.get("sum") or {}
    sent = end.get("sum_sent") or {}
    bps = recv.get("bits_per_second")
    retr = sent.get("retransmits")
    return (
        bps / 1e6 if isinstance(bps, (int, float)) else None,
        float(retr) if retr is not None else None
    )

def parse_udp(js):
    end = js.get("end", {})
    s = end.get("sum") or end.get("sum_received") or end.get("sum_sent") or {}
    bps = s.get("bits_per_second")
    jit = s.get("jitter_ms")
    lp = s.get("lost_percent")
    return (
        bps / 1e6 if isinstance(bps, (int, float)) else None,
        float(jit) if jit is not None else None,
        float(lp) if lp is not None else None
    )

# ping
ping_loss = ping_min = ping_avg = ping_max = ping_mdev = None
pf = os.path.join(tmp, "ping.txt")
if os.path.exists(pf):
    txt = open(pf, "r", encoding="utf-8", errors="ignore").read()
    m = re.search(r'([0-9.]+)% packet loss', txt)
    if m:
        ping_loss = float(m.group(1))
    m = re.search(r'=\s*([0-9.]+)/([0-9.]+)/([0-9.]+)/([0-9.]+)\s*ms', txt)
    if m:
        ping_min, ping_avg, ping_max, ping_mdev = map(float, m.groups())

# mtr last hop
mtr_loss = mtr_last = mtr_avg = mtr_best = mtr_wrst = mtr_stdev = None
mf = os.path.join(tmp, "mtr.txt")
if os.path.exists(mf):
    lines = open(mf, "r", encoding="utf-8", errors="ignore").read().splitlines()
    for line in reversed(lines):
        if "|--" in line:
            tokens = line.replace("|--", " ").replace("%", "").split()
            # hop ip loss snt last avg best wrst stdev
            if len(tokens) >= 9:
                try:
                    mtr_loss  = float(tokens[2])
                    mtr_last  = float(tokens[4])
                    mtr_avg   = float(tokens[5])
                    mtr_best  = float(tokens[6])
                    mtr_wrst  = float(tokens[7])
                    mtr_stdev = float(tokens[8])
                except Exception:
                    pass
            break

tcp_fwd_bps, tcp_fwd_retr = [], []
for js in load_jsons("tcp_fwd"):
    bps, retr = parse_tcp(js)
    if bps is not None: tcp_fwd_bps.append(bps)
    if retr is not None: tcp_fwd_retr.append(retr)

tcp_rev_bps, tcp_rev_retr = [], []
for js in load_jsons("tcp_rev"):
    bps, retr = parse_tcp(js)
    if bps is not None: tcp_rev_bps.append(bps)
    if retr is not None: tcp_rev_retr.append(retr)

udp_fwd_bps, udp_fwd_jit, udp_fwd_loss = [], [], []
for js in load_jsons("udp_fwd"):
    bps, jit, lp = parse_udp(js)
    if bps is not None: udp_fwd_bps.append(bps)
    if jit is not None: udp_fwd_jit.append(jit)
    if lp is not None: udp_fwd_loss.append(lp)

udp_rev_bps, udp_rev_jit, udp_rev_loss = [], [], []
for js in load_jsons("udp_rev"):
    bps, jit, lp = parse_udp(js)
    if bps is not None: udp_rev_bps.append(bps)
    if jit is not None: udp_rev_jit.append(jit)
    if lp is not None: udp_rev_loss.append(lp)

print("===== BEGIN SUMMARY =====")
print(f"label={label}")
print(f"server={server}")
print(f"tcp_p={tcp_p}")
print(f"udp_bw={udp_bw}")
print(f"repeat={repeat}")
print()
print("Ping:")
print(f"  loss_pct={fmt(ping_loss, 2)}")
if ping_avg is not None:
    print(f"  rtt_ms=min/avg/max/mdev={fmt(ping_min,3)}/{fmt(ping_avg,3)}/{fmt(ping_max,3)}/{fmt(ping_mdev,3)}")
else:
    print("  rtt_ms=min/avg/max/mdev=N/A")
print()
print("MTR(last hop):")
print(f"  loss_pct={fmt(mtr_loss, 2)}")
if mtr_avg is not None:
    print(f"  last/avg/best/wrst/stdev_ms={fmt(mtr_last,3)}/{fmt(mtr_avg,3)}/{fmt(mtr_best,3)}/{fmt(mtr_wrst,3)}/{fmt(mtr_stdev,3)}")
else:
    print("  last/avg/best/wrst/stdev_ms=N/A")
print()
print("TCP 正向 = 客户端出网 / 服务端入网")
print(f"  runs_mbps={fmt_list(tcp_fwd_bps, 2)}")
print(f"  median_mbps={fmt(med(tcp_fwd_bps), 2)}")
print(f"  runs_retr={[int(x) for x in tcp_fwd_retr] if tcp_fwd_retr else []}")
print(f"  median_retr={int(med(tcp_fwd_retr)) if tcp_fwd_retr else 'N/A'}")
print()
print("TCP 反向 = 客户端入网 / 服务端出网")
print(f"  runs_mbps={fmt_list(tcp_rev_bps, 2)}")
print(f"  median_mbps={fmt(med(tcp_rev_bps), 2)}")
print(f"  runs_retr={[int(x) for x in tcp_rev_retr] if tcp_rev_retr else []}")
print(f"  median_retr={int(med(tcp_rev_retr)) if tcp_rev_retr else 'N/A'}")
print()
print("UDP 正向 = 客户端出网 / 服务端入网")
print(f"  runs_mbps={fmt_list(udp_fwd_bps, 2)}")
print(f"  median_mbps={fmt(med(udp_fwd_bps), 2)}")
print(f"  runs_jitter_ms={fmt_list(udp_fwd_jit, 3)}")
print(f"  median_jitter_ms={fmt(med(udp_fwd_jit), 3)}")
print(f"  runs_loss_pct={fmt_list(udp_fwd_loss, 3)}")
print(f"  median_loss_pct={fmt(med(udp_fwd_loss), 3)}")
print()
print("UDP 反向 = 客户端入网 / 服务端出网")
print(f"  runs_mbps={fmt_list(udp_rev_bps, 2)}")
print(f"  median_mbps={fmt(med(udp_rev_bps), 2)}")
print(f"  runs_jitter_ms={fmt_list(udp_rev_jit, 3)}")
print(f"  median_jitter_ms={fmt(med(udp_rev_jit), 3)}")
print(f"  runs_loss_pct={fmt_list(udp_rev_loss, 3)}")
print(f"  median_loss_pct={fmt(med(udp_rev_loss), 3)}")
print("===== END SUMMARY =====")
PY

echo
echo "临时文件已自动清理。"
echo "你只需要复制上面的 BEGIN SUMMARY ~ END SUMMARY 给我。"
EOF
