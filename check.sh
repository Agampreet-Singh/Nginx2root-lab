#!/usr/bin/env bash
# Exposure check for the three lab targets (works on real servers too:
#   ./check.sh host:port [host:port ...]  ).
# For each target, reports the nginx version, whether HTTP/2 and HTTP/3 are
# advertised, and a verdict against the nginx2root fixed versions.
set -u

targets=("$@")
[ ${#targets[@]} -eq 0 ] && targets=(localhost:8443 localhost:9443 localhost:10443)

ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

is_patched() {
    local v=$1
    case $v in
        1.30.*) ver_ge "$v" 1.30.7 ;;
        1.31.*) ver_ge "$v" 1.31.9 ;;
        *)      ver_ge "$v" 1.32.0 ;;   # newer branches assumed fixed
    esac
}

printf '%-18s %-10s %-6s %-6s %s\n' TARGET VERSION H2 H3 VERDICT
for t in "${targets[@]}"; do
    hdrs=$(curl -sk -o /dev/null -D - --max-time 5 "https://$t/" 2>/dev/null)
    if [ -z "$hdrs" ]; then
        printf '%-18s %s\n' "$t" "unreachable"; continue
    fi
    ver=$(grep -i '^server:' <<<"$hdrs" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    proto=$(curl -sk -o /dev/null -w '%{http_version}' --http2 --max-time 5 "https://$t/")
    h2=$([ "$proto" = "2" ] && echo yes || echo no)
    h3=$(grep -qi '^alt-svc:.*h3' <<<"$hdrs" && echo yes || echo no)

    if [ -z "$ver" ]; then
        verdict="version hidden (server_tokens off) - check package version on the host"
    elif is_patched "$ver"; then
        verdict="PATCHED"
    elif [ "$h2" = no ] && [ "$h3" = no ]; then
        verdict="VULNERABLE BINARY, HTTP/2+3 off (mitigated for 3 of 5 CVEs)"
    else
        verdict="VULNERABLE - upgrade to 1.30.7 / 1.31.9"
    fi
    printf '%-18s %-10s %-6s %-6s %s\n' "$t" "${ver:-?}" "$h2" "$h3" "$verdict"
done
