#!/usr/bin/env bash
#
# Cloudflare DNS Management Script
# Helper script for common DNS operations — JSON output for AI consumption.
#
# Usage:
#   ./cloudflare-dns.sh <command> [args]
#
# Output Convention:
#   Success → stdout JSON: {"status": "ok", ...}
#   Error   → stderr JSON: {"error": "code", "hint": "...", "recoverable": true|false}
#   Exit codes: 0 = success, 1 = recoverable, 2 = fatal
#

set -euo pipefail

# Auto-load .env — priority: env vars (already set) > project-level .env > skill-level .env
# Lower-priority files are loaded first; higher-priority values override via `set -a`.
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 1. Skill-level .env (lowest priority for file-based config)
if [[ -f "$SKILL_DIR/.env" ]]; then
    set -a
    source "$SKILL_DIR/.env"
    set +a
fi

# 2. Project-level .env (overrides skill-level; current working directory)
if [[ -f "${PWD}/.env" ]] && [[ "${PWD}/.env" != "$SKILL_DIR/.env" ]]; then
    set -a
    source "${PWD}/.env"
    set +a
fi

# Cloudflare API base URL
CF_API="https://api.cloudflare.com/client/v4"

# ─── Output helpers ───

json_ok() {
    # Usage: json_ok '{"results": [...]}' "hint message"
    local data="$1"
    local hint="${2:-}"
    if [[ -n "$hint" ]]; then
        echo "$data" | jq --arg h "$hint" '. + {status: "ok", hint: $h}'
    else
        echo "$data" | jq '. + {status: "ok"}'
    fi
}

json_error() {
    # Usage: json_error "error_code" "hint message" [recoverable=true]
    local code="$1"
    local hint="$2"
    local recoverable="${3:-true}"
    cat >&2 <<EOF
{"error": "$code", "hint": "$hint", "recoverable": $recoverable}
EOF
}

# ─── Checks ───

check_token() {
    if [[ -z "${CF_API_TOKEN:-}" ]]; then
        json_error "missing_token" "CF_API_TOKEN not set. Create one at https://dash.cloudflare.com/profile/api-tokens with Zone:Read + DNS:Edit permissions." true
        exit 1
    fi
}

check_zone_id() {
    local zone_id="${1:-}"
    if [[ -z "$zone_id" ]]; then
        json_error "missing_zone_id" "Zone ID required. Pass as argument or set CF_ZONE_ID environment variable." true
        exit 1
    fi
}

# ─── API request helper ───

cf_api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"

    local args=(-s -X "$method")
    args+=(-H "Authorization: Bearer $CF_API_TOKEN")
    args+=(-H "Content-Type: application/json")

    if [[ -n "$data" ]]; then
        args+=(-d "$data")
    fi

    curl "${args[@]}" "${CF_API}${endpoint}"
}

# Check if Cloudflare API response was successful
cf_check_success() {
    local result="$1"
    echo "$result" | jq -e '.success == true' > /dev/null 2>&1
}

# Extract error from Cloudflare API response and report with recovery hints
cf_handle_error() {
    local result="$1"
    local operation="$2"
    local msg code
    msg=$(echo "$result" | jq -r '.errors[0].message // "Unknown error"')
    code=$(echo "$result" | jq -r '.errors[0].code // 0')

    # Detect auth failures (expired/revoked/invalid tokens) and provide re-auth guidance
    if [[ "$code" == "9109" || "$code" == "6003" || "$code" == "6111" || "$msg" == *"authentication"* || "$msg" == *"Authorization"* ]]; then
        json_error "auth_failed" "$operation failed: $msg. Token may be expired or revoked. Re-run preflight, then follow First-time Setup to regenerate at https://dash.cloudflare.com/profile/api-tokens" true
    elif [[ "$code" == "6007" || "$msg" == *"Forbidden"* || "$msg" == *"permission"* ]]; then
        json_error "permission_denied" "$operation failed: $msg. Token lacks required permissions (Zone:Read + DNS:Edit). Regenerate at https://dash.cloudflare.com/profile/api-tokens" true
    else
        json_error "api_error" "$operation failed: $msg" true
    fi
}

# ─── Commands ───

cmd_verify_token() {
    check_token

    # Test actual capability (list zones) instead of meta-verify endpoint,
    # because /user/tokens/verify only works for User-level tokens,
    # not Account-level tokens.
    local result
    result=$(cf_api GET "/zones?per_page=1")

    if cf_check_success "$result"; then
        local zone_count
        zone_count=$(echo "$result" | jq '.result_info.total_count // 0')
        json_ok "{\"token_status\": \"active\", \"accessible_zones\": $zone_count}" "Token is valid ($zone_count zone(s) accessible)"
    else
        cf_handle_error "$result" "Token verification"
        exit 1
    fi
}

cmd_list_zones() {
    check_token

    local result
    result=$(cf_api GET "/zones?per_page=50")

    if cf_check_success "$result"; then
        local count
        count=$(echo "$result" | jq '.result | length')
        echo "$result" | jq --arg h "$count zone(s) found" '{
            status: "ok",
            hint: $h,
            results: [.result[] | {name, id, status}]
        }'
    else
        cf_handle_error "$result" "List zones"
        exit 1
    fi
}

cmd_list_records() {
    check_token
    local zone_id="${1:-${CF_ZONE_ID:-}}"
    check_zone_id "$zone_id"

    local result
    result=$(cf_api GET "/zones/$zone_id/dns_records?per_page=5000")

    if cf_check_success "$result"; then
        local count
        count=$(echo "$result" | jq '.result | length')
        echo "$result" | jq --arg h "$count record(s) found" '{
            status: "ok",
            hint: $h,
            results: [.result[] | {type, name, content, proxied, ttl, id}]
        }'
    else
        cf_handle_error "$result" "List records"
        exit 1
    fi
}

cmd_get_record() {
    check_token
    local zone_id="${1:-}"
    local name="${2:-}"

    if [[ -z "$zone_id" || -z "$name" ]]; then
        json_error "missing_args" "Zone ID and record name required. Usage: get-record <zone_id> <name>" true
        exit 1
    fi

    local result
    result=$(cf_api GET "/zones/$zone_id/dns_records?name=$name")

    if cf_check_success "$result"; then
        local count
        count=$(echo "$result" | jq '.result | length')
        echo "$result" | jq --arg h "$count record(s) matching '$name'" '{
            status: "ok",
            hint: $h,
            results: [.result[] | {type, name, content, proxied, ttl, id}]
        }'
    else
        cf_handle_error "$result" "Get record"
        exit 1
    fi
}

cmd_create_a() {
    check_token
    local zone_id="${1:-}"
    local name="${2:-}"
    local ip="${3:-}"
    local proxied="${4:-true}"

    if [[ -z "$zone_id" || -z "$name" || -z "$ip" ]]; then
        json_error "missing_args" "Zone ID, name, and IP required. Usage: create-a <zone_id> <name> <ip> [proxied]" true
        exit 1
    fi

    local result
    result=$(cf_api POST "/zones/$zone_id/dns_records" "{
        \"type\": \"A\",
        \"name\": \"$name\",
        \"content\": \"$ip\",
        \"ttl\": 1,
        \"proxied\": $proxied
    }")

    if cf_check_success "$result"; then
        echo "$result" | jq '{
            status: "ok",
            hint: "A record created",
            record: {id: .result.id, name: .result.name, content: .result.content, proxied: .result.proxied}
        }'
    else
        cf_handle_error "$result" "Create A record"
        exit 1
    fi
}

cmd_create_cname() {
    check_token
    local zone_id="${1:-}"
    local name="${2:-}"
    local target="${3:-}"
    local proxied="${4:-true}"

    if [[ -z "$zone_id" || -z "$name" || -z "$target" ]]; then
        json_error "missing_args" "Zone ID, name, and target required. Usage: create-cname <zone_id> <name> <target> [proxied]" true
        exit 1
    fi

    local result
    result=$(cf_api POST "/zones/$zone_id/dns_records" "{
        \"type\": \"CNAME\",
        \"name\": \"$name\",
        \"content\": \"$target\",
        \"ttl\": 1,
        \"proxied\": $proxied
    }")

    if cf_check_success "$result"; then
        echo "$result" | jq '{
            status: "ok",
            hint: "CNAME record created",
            record: {id: .result.id, name: .result.name, content: .result.content, proxied: .result.proxied}
        }'
    else
        cf_handle_error "$result" "Create CNAME record"
        exit 1
    fi
}

cmd_delete_record() {
    check_token
    local zone_id="${1:-}"
    local record_id="${2:-}"

    if [[ -z "$zone_id" || -z "$record_id" ]]; then
        json_error "missing_args" "Zone ID and record ID required. Usage: delete-record <zone_id> <record_id>" true
        exit 1
    fi

    local result
    result=$(cf_api DELETE "/zones/$zone_id/dns_records/$record_id")

    if cf_check_success "$result"; then
        json_ok "{\"deleted_id\": \"$record_id\"}" "Record $record_id deleted"
    else
        cf_handle_error "$result" "Delete record"
        exit 1
    fi
}

cmd_export() {
    check_token
    local zone_id="${1:-${CF_ZONE_ID:-}}"
    check_zone_id "$zone_id"

    local filename="zone-export-$(date +%Y%m%d-%H%M%S).txt"

    cf_api GET "/zones/$zone_id/dns_records/export" > "$filename"

    if [[ -s "$filename" ]]; then
        local count
        count=$(grep -c '^[^;]' "$filename" || echo 0)
        json_ok "{\"file\": \"$filename\", \"record_count\": $count}" "Zone exported to $filename ($count records)"
    else
        rm -f "$filename"
        json_error "export_failed" "Export failed or zone is empty" true
        exit 1
    fi
}

cmd_check_external_dns() {
    local pods_ok=false logs=""

    if command -v kubectl &>/dev/null; then
        if kubectl get pods -n external-dns -o json &>/dev/null; then
            pods_ok=true
            local pod_info
            pod_info=$(kubectl get pods -n external-dns -o json | jq '[.items[] | {name: .metadata.name, status: .status.phase, ready: (.status.containerStatuses[0].ready // false)}]')
            local error_lines
            error_lines=$(kubectl logs -n external-dns deployment/external-dns --tail=100 2>/dev/null | grep -i error || true)

            cat <<EOF | jq '.'
{
    "status": "ok",
    "hint": "External-DNS status retrieved",
    "pods": $pod_info,
    "recent_errors": $(echo "$error_lines" | jq -R -s 'split("\n") | map(select(. != ""))')
}
EOF
        else
            json_error "k8s_access" "Cannot access external-dns namespace. Check kubectl context and permissions." true
            exit 1
        fi
    else
        json_error "missing_kubectl" "kubectl not found. Install kubectl to use Kubernetes features." false
        exit 2
    fi
}

cmd_verify_dns() {
    local hostname="${1:-}"

    if [[ -z "$hostname" ]]; then
        json_error "missing_args" "Hostname required. Usage: verify-dns <hostname>" true
        exit 1
    fi

    if ! command -v dig &>/dev/null; then
        json_error "missing_dig" "dig not found. Install bind-utils or dnsutils." false
        exit 2
    fi

    local a_records aaaa_records txt_records ip proxy_status

    a_records=$(dig @1.1.1.1 "$hostname" A +short | jq -R -s 'split("\n") | map(select(. != ""))')
    aaaa_records=$(dig @1.1.1.1 "$hostname" AAAA +short | jq -R -s 'split("\n") | map(select(. != ""))')
    txt_records=$(dig @1.1.1.1 "_externaldns.$hostname" TXT +short | jq -R -s 'split("\n") | map(select(. != ""))')

    ip=$(dig +short "$hostname" | head -1)
    if [[ "$ip" =~ ^104\.|^172\.64\.|^141\.101\. ]]; then
        proxy_status="proxied"
    elif [[ -n "$ip" ]]; then
        proxy_status="dns_only"
    else
        proxy_status="unresolved"
    fi

    cat <<EOF | jq '.'
{
    "status": "ok",
    "hint": "DNS verification for $hostname (proxy: $proxy_status)",
    "hostname": "$hostname",
    "a_records": $a_records,
    "aaaa_records": $aaaa_records,
    "txt_ownership": $txt_records,
    "proxy_status": "$proxy_status",
    "resolved_ip": "$ip"
}
EOF
}

cmd_preflight() {
    local ready=true

    # Check dependencies
    local curl_ok=false jq_ok=false dig_ok=false kubectl_ok=false
    command -v curl &>/dev/null && curl_ok=true
    command -v jq &>/dev/null && jq_ok=true
    command -v dig &>/dev/null && dig_ok=true
    command -v kubectl &>/dev/null && kubectl_ok=true

    if ! $curl_ok || ! $jq_ok; then ready=false; fi

    # Check credentials (live validation — test actual API access, not just env var existence)
    local token_status="not_configured" zone_status="not_configured" token_valid=false token_hint=""
    if [[ -n "${CF_API_TOKEN:-}" ]]; then
        token_status="configured"
        token_hint="Token is set but not yet validated"
        if $curl_ok && $jq_ok; then
            # Test actual capability (list zones with per_page=1) instead of
            # meta-verify endpoint, because /user/tokens/verify only works for
            # User-level tokens, not Account-level tokens.
            local verify
            verify=$(curl -s -X GET "${CF_API}/zones?per_page=1" \
                -H "Authorization: Bearer $CF_API_TOKEN" \
                -H "Content-Type: application/json" 2>/dev/null || echo '{"success":false}')
            if echo "$verify" | jq -e '.success == true' &>/dev/null; then
                token_valid=true
                token_hint="Token is valid (live API check passed)"
            else
                ready=false
                token_status="invalid"
                local api_msg
                api_msg=$(echo "$verify" | jq -r '.errors[0].message // "API call failed (network error or malformed token)"' 2>/dev/null)
                token_hint="Live validation failed: $api_msg. Regenerate at https://dash.cloudflare.com/profile/api-tokens"
            fi
        else
            token_hint="Cannot validate — curl or jq missing. Install them first, then re-run preflight."
        fi
    else
        ready=false
        token_hint="CF_API_TOKEN not set. Create at https://dash.cloudflare.com/profile/api-tokens with Zone:Read + DNS:Edit"
    fi

    [[ -n "${CF_ZONE_ID:-}" ]] && zone_status="configured"

    # Build the JSON output string
    local output
    output=$(cat <<EOF
{"ready":$ready,"dependencies":{"curl":{"status":"$(if $curl_ok; then echo ok; else echo missing; fi)","hint":"brew install curl"},"jq":{"status":"$(if $jq_ok; then echo ok; else echo missing; fi)","hint":"brew install jq"},"dig":{"status":"$(if $dig_ok; then echo ok; else echo missing; fi)","hint":"brew install bind (optional, for DNS verification)"},"kubectl":{"status":"$(if $kubectl_ok; then echo ok; else echo missing; fi)","hint":"brew install kubectl (optional, for External-DNS)"}},"credentials":{"CF_API_TOKEN":{"status":"$token_status","valid":$token_valid,"required":true,"hint":"$token_hint"},"CF_ZONE_ID":{"status":"$zone_status","required":false,"hint":"Find in Cloudflare dashboard - zone overview (right sidebar)"}},"hint":"$(if $ready; then echo 'All checks passed, ready to use'; else echo 'Some checks failed, see details above'; fi)"}
EOF
)

    # Pretty-print with jq if available; otherwise output raw JSON (bootstrap-safe)
    if $jq_ok; then
        echo "$output" | jq '.'
    else
        printf '%s\n' "$output"
    fi

    if ! $ready; then exit 1; fi
}

cmd_help() {
    cat <<EOF | jq '.'
{
    "status": "ok",
    "hint": "Available commands listed below",
    "commands": [
        {"name": "preflight", "args": "", "description": "Check environment readiness"},
        {"name": "verify-token", "args": "", "description": "Verify API token validity"},
        {"name": "list-zones", "args": "", "description": "List all zones"},
        {"name": "list-records", "args": "[zone_id]", "description": "List DNS records for a zone"},
        {"name": "get-record", "args": "<zone_id> <name>", "description": "Get specific record by name"},
        {"name": "create-a", "args": "<zone_id> <name> <ip> [proxied]", "description": "Create A record"},
        {"name": "create-cname", "args": "<zone_id> <name> <target> [proxied]", "description": "Create CNAME record"},
        {"name": "delete-record", "args": "<zone_id> <record_id>", "description": "Delete record"},
        {"name": "export", "args": "<zone_id>", "description": "Export zone to BIND format"},
        {"name": "check-external-dns", "args": "", "description": "Check External-DNS in Kubernetes"},
        {"name": "verify-dns", "args": "<hostname>", "description": "Verify DNS resolution"}
    ]
}
EOF
}

# Main
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        preflight)           cmd_preflight "$@" ;;
        verify-token)        cmd_verify_token "$@" ;;
        list-zones)          cmd_list_zones "$@" ;;
        list-records)        cmd_list_records "$@" ;;
        get-record)          cmd_get_record "$@" ;;
        create-a)            cmd_create_a "$@" ;;
        create-cname)        cmd_create_cname "$@" ;;
        delete-record)       cmd_delete_record "$@" ;;
        export)              cmd_export "$@" ;;
        check-external-dns)  cmd_check_external_dns "$@" ;;
        verify-dns)          cmd_verify_dns "$@" ;;
        help|--help|-h)      cmd_help ;;
        *)
            json_error "unknown_command" "Unknown command: $command. Run with 'help' for usage." true
            exit 1
            ;;
    esac
}

main "$@"
