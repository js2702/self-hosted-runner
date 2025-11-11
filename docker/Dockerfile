FROM ubuntu:20.04

ARG RUNNER_VERSION="2.317.0"
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg lsb-release \
    build-essential libssl-dev libffi-dev python3 python3-venv python3-dev python3-pip jq ssh \
    libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev && \
    rm -rf /var/lib/apt/lists/*

RUN if ! getent group docker >/dev/null 2>&1; then groupadd docker; fi && \
    if ! id -u docker >/dev/null 2>&1; then useradd -m -g docker docker; fi && \
    usermod -aG docker docker

RUN cd /home/docker && mkdir -p actions-runner && cd actions-runner && \
    case "${TARGETARCH}" in \
      amd64) RUNNER_ARCH="x64" ;; \
      arm64) RUNNER_ARCH="arm64" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -fsSL -o actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
      https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz && \
    tar xzf actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz && \
    rm actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz

RUN chown -R docker:docker /home/docker && \
    /home/docker/actions-runner/bin/installdependencies.sh

COPY start.sh /start.sh
RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]
