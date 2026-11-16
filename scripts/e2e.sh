#!/usr/bin/env bash
# End-to-end test of the chart on a throwaway cluster (kind in CI).
#
#   scripts/e2e.sh install   install with a locally loaded image (t3code-ci:ci)
#   scripts/e2e.sh smoke     helm test + API check + pairing + agent install
#   scripts/e2e.sh debug     dump state
#
# Env: NS (default t3-e2e), RELEASE (default t3), IMAGE_REPO, IMAGE_TAG,
#      KUBE_CONTEXT (default kind-t3: never the current context, which may be a real cluster)
set -euo pipefail

KUBE_CONTEXT="${KUBE_CONTEXT:-kind-t3}"
kubectl() { command kubectl --context "$KUBE_CONTEXT" "$@"; }
helm() { command helm --kube-context "$KUBE_CONTEXT" "$@"; }

NS="${NS:-t3-e2e}"
RELEASE="${RELEASE:-t3}"
CHART="${CHART:-charts/t3code}"
IMAGE_REPO="${IMAGE_REPO:-t3code-ci}"
IMAGE_TAG="${IMAGE_TAG:-ci}"
STS="${RELEASE}-t3code"
POD="${STS}-0"

install() {
  kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
  # Fails the install if anything in the chart violates the "restricted" profile.
  kubectl label namespace "$NS" --overwrite \
    pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/warn=restricted

  helm upgrade --install "$RELEASE" "$CHART" -n "$NS" --wait --timeout 10m \
    --set image.registry="" \
    --set image.repository="$IMAGE_REPO" \
    --set image.tag="$IMAGE_TAG" \
    --set image.pullPolicy=Never \
    --set t3.publicUrl=https://t3.e2e.test \
    --set "agents.packages={is-number@7.0.0}" \
    --set agents.strict=true \
    --set networkPolicy.enabled=true \
    --set persistence.home.size=1Gi \
    --set persistence.workspace.size=1Gi \
    --set resources.requests.cpu=100m \
    --set resources.requests.memory=256Mi
}

smoke() {
  kubectl -n "$NS" rollout status "statefulset/$STS" --timeout=5m

  echo "== helm test"
  helm test "$RELEASE" -n "$NS" --logs

  echo "== runs as uid 1000, no SA token"
  # shellcheck disable=SC2016 # expanded inside the pod
  kubectl -n "$NS" exec "$POD" -c t3code -- sh -c 'test "$(id -u)" = 1000'
  if kubectl -n "$NS" exec "$POD" -c t3code -- test -e /var/run/secrets/kubernetes.io/serviceaccount/token; then
    echo "ServiceAccount token is mounted" >&2; exit 1
  fi

  echo "== t3 version matches appVersion"
  want="$(awk -F'"' '/^appVersion:/{print $2}' "$CHART/Chart.yaml")"
  got="$(kubectl -n "$NS" exec "$POD" -c t3code -- t3 --version)"
  echo "$got"; [[ "$got" == *"$want"* ]]

  echo "== agent installed on the home volume"
  kubectl -n "$NS" exec "$POD" -c t3code -- test -d /home/t3/.local/lib/node_modules/is-number

  echo "== pairing link uses the public URL"
  out="$(kubectl -n "$NS" exec "$POD" -c t3code -- t3-pair --label e2e --ttl 30m)"
  grep -q 'https://t3.e2e.test/pair#token=' <<<"$out"

  echo "== state survives a restart"
  kubectl -n "$NS" delete pod "$POD" --wait
  kubectl -n "$NS" rollout status "statefulset/$STS" --timeout=5m
  kubectl -n "$NS" wait --for=condition=Ready "pod/$POD" --timeout=5m
  kubectl -n "$NS" exec "$POD" -c t3code -- t3 auth pairing list | grep -q e2e

  echo "smoke OK"
}

debug() {
  set +e
  kubectl -n "$NS" get all,pvc,netpol -o wide
  kubectl -n "$NS" describe pod "$POD"
  kubectl -n "$NS" logs "$POD" -c install-agents --tail=100
  # Startup logs carry the owner pairing token: plain, URL-encoded and as a QR code.
  kubectl -n "$NS" logs "$POD" -c t3code --tail=200 \
    | sed -E 's/(token=|token%3D|Token: )[A-Za-z0-9_-]+/\1REDACTED/g; /[█▀▄]/d'
  kubectl -n "$NS" get events --sort-by=.lastTimestamp | tail -40
}

"${1:?usage: $0 install|smoke|debug}"
