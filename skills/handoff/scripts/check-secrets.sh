#!/usr/bin/env bash
# Fail when a file holds something that looks like a secret.
set -euo pipefail

usage() {
    cat << 'EOF'
Usage: check-secrets.sh [--regex] <file>

Scans one file for secrets. Uses gitleaks when it is installed, otherwise a regex fallback
(private keys, AWS keys, GitHub and GitLab tokens, password=..., bearer tokens).

Options:
  --regex     Use the regex fallback even when gitleaks is installed
  -h, --help  Show this help

Exit codes: 0 no finding, 1 findings (printed with the secret redacted), 2 usage error.
EOF
}

use_gitleaks=true
case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
    --regex)
        use_gitleaks=false
        shift
        ;;
esac
[[ $# -gt 0 ]] || {
    usage >&2
    exit 2
}
[[ $# -eq 1 ]] || {
    echo "error: expected one file, got $#" >&2
    exit 2
}
file="$1"
[[ -f "${file}" && -r "${file}" ]] || {
    echo "error: '${file}' is not a readable file" >&2
    exit 2
}

if [[ "${use_gitleaks}" == true ]] && command -v gitleaks > /dev/null; then
    if gitleaks dir --no-banner --no-color --redact --verbose --log-level warn --exit-code 1 "${file}"; then
        echo "ok: gitleaks found no secret in ${file}"
        exit 0
    fi
    echo "error: gitleaks found secrets in ${file} (or failed): redact them and run again" >&2
    exit 1
fi

# name<TAB>extended regex. Kept broad on purpose: a false positive costs one redaction.
patterns="$(
    cat << 'EOF'
private key	-----BEGIN [A-Z ]*PRIVATE KEY-----
AWS access key	(AKIA|ASIA)[0-9A-Z]{16}
AWS secret key	aws_secret_access_key[[:space:]]*[=:][[:space:]]*[A-Za-z0-9/+=]{40}
GitHub token	(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}
GitLab token	gl(pat|dt|rt|ptt|cbt|soat)-[A-Za-z0-9_-]{20,}
password	(password|passwd|pwd)[[:space:]]*[=:][[:space:]]*[^[:space:]<]{4,}
bearer token	[Bb]earer[[:space:]]+[A-Za-z0-9._~+/-]{16,}=*
EOF
)"

findings=0
while IFS=$'\t' read -r name regex; do
    # Print the line numbers only, never the matching text.
    lines="$(grep -nE -i -e "${regex}" "${file}" | cut -d: -f1 | paste -sd, -)" || true
    if [[ -n "${lines}" ]]; then
        echo "${file}: ${name} on line(s) ${lines}" >&2
        findings=$((findings + 1))
    fi
done <<< "${patterns}"

if [[ ${findings} -gt 0 ]]; then
    echo "error: ${findings} kind(s) of secret found (regex fallback): redact them and run again" >&2
    exit 1
fi
echo "ok: no secret found in ${file} (regex fallback; install gitleaks for a wider scan)"
