#!/bin/bash
set -euo pipefail

REPO="${REPO:-}"
REG_TOKEN="${REG_TOKEN:-}"
NAME="${NAME:-}"

RUNNER_DIR="/home/docker/actions-runner"
RUNNER_FLAG="--runner-mode"

if [ "$(id -u)" -eq 0 ] && { [ "${1:-}" != "${RUNNER_FLAG}" ]; }; then
  export HOME="/home/docker"
  exec env HOME="/home/docker" \
    REPO="${REPO}" REG_TOKEN="${REG_TOKEN}" NAME="${NAME}" \
    su docker -s /bin/bash -c "/start.sh ${RUNNER_FLAG}"
fi

if [ "${1:-}" = "${RUNNER_FLAG}" ]; then
  shift
fi

for required in REPO REG_TOKEN NAME; do
  if [ -z "${!required}" ]; then
    echo "Environment variable ${required} must be set."
    exit 1
  fi
done

cd "${RUNNER_DIR}" || exit 1
./config.sh --unattended --replace \
  --url "https://github.com/${REPO}" \
  --token "${REG_TOKEN}" \
  --name "${NAME}" \
  --work "_work"

cleanup() {
  echo "Removing runner..."
  ./config.sh remove --unattended --token "${REG_TOKEN}"
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh & wait $!
