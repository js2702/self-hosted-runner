#!/bin/bash
set -euo pipefail

REPO="${REPO:-}"
REG_TOKEN="${REG_TOKEN:-}"
NAME="${NAME:-}"

RUNNER_DIR="/home/docker/actions-runner"
DOCKERD_LOG="${DOCKERD_LOG:-/var/log/dockerd.log}"
DOCKERD_PID_FILE="${DOCKERD_PID_FILE:-/var/run/docker.pid}"
DOCKER_START_TIMEOUT="${DOCKER_START_TIMEOUT:-30}"
RUNNER_FLAG="--runner-mode"

# Launch dockerd in the background and wait for the socket to become available.
start_docker() {
  echo "Starting Docker daemon..."
  if [ -f "${DOCKERD_PID_FILE}" ]; then
    existing_pid="$(cat "${DOCKERD_PID_FILE}" 2>/dev/null || true)"
    if [ -n "${existing_pid}" ] && kill -0 "${existing_pid}" 2>/dev/null; then
      echo "Docker daemon already running with PID ${existing_pid}"
      return
    fi
    echo "Removing stale Docker PID file at ${DOCKERD_PID_FILE}"
    rm -f "${DOCKERD_PID_FILE}"
  fi

  if pgrep -x dockerd >/dev/null 2>&1; then
    echo "Docker daemon already running (detected via pgrep)."
    return
  fi

  mkdir -p "$(dirname "${DOCKERD_LOG}")"
  nohup /usr/bin/dockerd --pidfile "${DOCKERD_PID_FILE}" >"${DOCKERD_LOG}" 2>&1 &

  local elapsed=0
  until docker info >/dev/null 2>&1; do
    if [ "${elapsed}" -ge "${DOCKER_START_TIMEOUT}" ]; then
      echo "Docker daemon failed to start within ${DOCKER_START_TIMEOUT}s"
      tail -n 200 "${DOCKERD_LOG}" || true
      exit 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  echo "Docker daemon is ready."
}

if [ "$(id -u)" -eq 0 ] && { [ "${1:-}" != "${RUNNER_FLAG}" ]; }; then
  start_docker
  export HOME="/home/docker"
  exec env HOME="/home/docker" \
    REPO="${REPO}" REG_TOKEN="${REG_TOKEN}" NAME="${NAME}" \
    DOCKER_START_TIMEOUT="${DOCKER_START_TIMEOUT}" \
    DOCKERD_LOG="${DOCKERD_LOG}" DOCKERD_PID_FILE="${DOCKERD_PID_FILE}" \
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
