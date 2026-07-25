# Guards the promise in the repo's name. Model routing tables and behavioural claims are
# dated; nothing else forces a re-check, so this fails when they age past the window.
# A "maintained" repo whose claims are six months stale is worse than one that never
# made the claim.
MAX_DAYS="${MAX_DAYS:-90}"
now=$(date +%s)
stale=0; checked=0

for f in "$SKILLS_DIR"/*/SKILL.md; do
  d=$(grep -oE 'as of [0-9]{4}-[0-9]{2}-[0-9]{2}' "$f" 2>/dev/null | head -1 | grep -oE '[0-9-]{10}')
  [ -z "$d" ] && continue
  checked=$((checked+1))
  # BSD date needs an explicit time — `-f '%Y-%m-%d'` alone exits 0 and silently
  # returns the CURRENT epoch, making every date look zero days old.
  then_s=$(date -j -f '%Y-%m-%d %H:%M:%S' "$d 00:00:00" +%s 2>/dev/null \
           || date -d "$d" +%s 2>/dev/null || echo "")
  [ -z "$then_s" ] && { _no "date parse for $d" "could not parse"; continue; }
  age=$(( (now - then_s) / 86400 ))
  if [ "$age" -gt "$MAX_DAYS" ]; then
    stale=$((stale+1))
    _no "$(basename "$(dirname "$f")") routing dated $d" "$age days old, limit $MAX_DAYS — re-verify against current model docs"
  fi
done

[ "$checked" -gt 0 ] && _ok "found $checked dated routing table(s)" \
  || _no "dated routing tables" "none found — the maintenance promise is unenforced"
[ "$stale" -eq 0 ] && _ok "all routing tables within $MAX_DAYS days"
