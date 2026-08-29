# ---- Stage 1: build -----------------------------------------------------
# The tag is readable; in production this line would carry the digest as well
# (python:3.12-slim@sha256:...) so that the same Dockerfile always resolves to
# the identical base layer. Immutability of the *application* artefact is
# guaranteed regardless, because deployments reference the image by digest.
FROM python:3.12-slim AS build

WORKDIR /build
COPY requirements.txt .
# Upgrade the build tooling before installing. pip, setuptools and wheel ship
# with the base image and are a common source of fixable CRITICAL findings;
# patching them here is a real remediation rather than a suppression.
RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
 && pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Stage 2: runtime ---------------------------------------------------
FROM python:3.12-slim AS runtime

# Run as an unprivileged user: a container breakout should not land on root.
# Patch OS packages and the bundled Python tooling in the runtime layer too,
# then create an unprivileged account for the application to run under.
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && rm -rf /var/lib/apt/lists/* \
 && pip install --no-cache-dir --upgrade pip setuptools wheel \
 && groupadd --gid 10001 appgrp \
 && useradd --uid 10001 --gid appgrp --no-create-home --shell /usr/sbin/nologin appusr

WORKDIR /srv/app
COPY --from=build /install /usr/local
COPY app/ ./app/

# Injected by the pipeline so /healthz reports exactly which build is live.
ARG APP_VERSION=0.0.0-dev
ENV APP_VERSION=${APP_VERSION} \
    PYTHONPATH=/srv/app \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

USER 10001:10001
EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/healthz').status==200 else 1)"

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", \
     "--access-logfile", "-", "app.main:create_app()"]
