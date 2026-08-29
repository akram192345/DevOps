# fintech-ledger-api

Supporting artefacts for **Deliverable 2** of the DevOps Delivery Strategy portfolio
(Scenario A — the fintech app with painful release weekends).

The application is deliberately trivial: a small ledger API that credits and debits
accounts in exact minor units. What is being evidenced is the DevOps machinery around
it — version control discipline, an automated pipeline, and reproducible infrastructure.

## What is in here

| Artefact | Path | Evidences |
|---|---|---|
| Commit history, feature branch, merge, tags | `docs/git-history.txt` | Part 2 |
| CI pipeline (build, lint, SAST, tests, scan, gate) | `.github/workflows/ci.yml` | Part 3 |
| Blue–green CD with automated rollback | `.github/workflows/cd.yml` | Part 3 |
| Container image (multi-stage, non-root) | `Dockerfile` | Part 4 |
| Local environment parity | `docker-compose.yml` | Part 4 |
| Infrastructure as code | `infra/terraform/main.tf` | Part 4, Part 6 |

## Branching model

Trunk-based development. `main` is always releasable and is protected: no direct
pushes, two approving reviews, and the `quality-gate` check must pass. Feature
branches live for under two days and merge back via a pull request with `--no-ff`
so the merge point stays visible in the history for auditors.

## Releases

Semantic versioning with annotated tags. Each tag is the audit anchor: the tag
message records what changed, and the pipeline attaches the test results, the
image digest and the security scan to that tag.

## Running it

```bash
pip install -r requirements-dev.txt
pytest                      # 15 tests, coverage gate at 80%
docker compose up --build   # http://localhost:8000/healthz
```
