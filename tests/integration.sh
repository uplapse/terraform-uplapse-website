#!/usr/bin/env bash
# The module through the real provider against the provider's in-memory mock API: apply, re-plan (must be empty),
# change the mailbox protocol and the uptime check type, re-plan, destroy.
#
#   PROVIDER_DIR=../terraform-provider-uplapse tests/integration.sh
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
provider_dir=$(cd "${PROVIDER_DIR:-$here/../../terraform-provider-uplapse}" && pwd)
work=$(mktemp -d)
trap 'kill "${mock_pid:-0}" 2>/dev/null || true; rm -rf "$work"' EXIT

(cd "$provider_dir" && go build -o "$work/bin/terraform-provider-uplapse" . && go build -o "$work/mockserver" ./internal/mockapi/cmd/mockserver)
port=$((20000 + RANDOM % 20000))
"$work/mockserver" -addr "127.0.0.1:$port" -key upm_it_key >"$work/mock.log" 2>&1 &
mock_pid=$!
for _ in $(seq 50); do curl -s -o /dev/null "http://127.0.0.1:$port/" && break; sleep 0.1; done

cat >"$work/dev.tfrc" <<TFRC
provider_installation {
  dev_overrides { "uplapse/uplapse" = "$work/bin" }
  direct {}
}
TFRC
export TF_CLI_CONFIG_FILE="$work/dev.tfrc" TF_IN_AUTOMATION=1
export TF_VAR_endpoint="http://127.0.0.1:$port" TF_VAR_api_key=upm_it_key
cp "$here/integration/main.tf" "$work/"
sed -i "s#source = \"../..\"#source = \"$(cd "$here/.." && pwd)\"#" "$work/main.tf"
cd "$work"
tf() { terraform "$@" -no-color -input=false; }

tf init -backend=false >/dev/null
tf apply -auto-approve >/dev/null
echo "apply: $(terraform output -json ids | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))') monitors"
tf plan -detailed-exitcode >/dev/null || { echo "FAIL: plan after apply is not empty"; tf plan; exit 1; }
echo "re-plan: no changes"

tf apply -auto-approve -var mailbox_protocol=SUBMISSION -var keyword=Welcome >/dev/null
tf plan -detailed-exitcode -var mailbox_protocol=SUBMISSION -var keyword=Welcome >/dev/null || { echo "FAIL: plan after update is not empty"; exit 1; }
port_now=$(terraform state show -no-color 'module.site.uplapse_monitor.mail_server["mailbox"]' | awk '$1=="port"{print $3}')
[ "$port_now" = 587 ] || { echo "FAIL: mailbox port $port_now after moving to SUBMISSION, want 587"; exit 1; }
type_now=$(terraform state show -no-color 'module.site.uplapse_monitor.uptime[0]' | awk '$1=="type"{print $3}')
[ "$type_now" = '"KEYWORD"' ] || { echo "FAIL: uptime type $type_now, want KEYWORD"; exit 1; }
echo "update: mailbox on 587, uptime is a keyword check, re-plan empty"

tf destroy -auto-approve -var mailbox_protocol=SUBMISSION -var keyword=Welcome >/dev/null
left=$(curl -s -H "x-api-key: upm_it_key" "http://127.0.0.1:$port/v1/monitor/1" -o /dev/null -w '%{http_code}')
echo "destroy: done (monitor 1 now $left)"
echo "PASS"
