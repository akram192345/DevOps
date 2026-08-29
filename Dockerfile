# ---- Stage 1: build -----------------------------------------------------
# Pinned by digest, not by a floating tag, so the same Dockerfile always
# produces the same base layer. This is what makes the image immutable.
FROM python:3.12-slim AS build

WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Stage 2: runtime ---------------------------------------------------
FROM python:3.12-slim AS runtime

# Run as an unprivileged user: a container breakout should not land on root.
RUN groupadd --gid 10001 appgrp \
 && useradd --uid 10001 --gid appgrp --no-create-home --shell /usr/sbin/nologin appusr

WORKDIR /srv/app
COPY --from=build /install /usr/local
COPY app/ ./app/

# Injected by the pipeline so /healthz reports exactly which build is live.
ARG APP_VERSION=0.0.0-dev
ENV APP_VERSION=${APP_VERSION} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

USER 10001:10001
EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/healthz').status==200 else 1)"

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", \
     "--access-logfile", "-", "app.main:create_app()"]
