# FestPass Container Security Assessment

## Personal details

- Name: Not supplied; enter your name before submission.
- REGNO: `8047`
- PORT: `8047`
- Docker Hub username: `devdeveloper4321`
- Docker Hub repository: https://hub.docker.com/r/devdeveloper4321/fest-backend
- AI tools: GitHub Copilot was used to scaffold and review the application, Compose configuration, and command documentation. All commands, scans, screenshots, publishing, and signing must be run and captured by the student.

## Implementation and evidence status

The baseline and hardened images were built locally. The baseline health endpoint and mocked Flask health/GET/POST route checks passed. The full Compose stack was attempted, but backend-to-PostgreSQL traffic timed out in this Docker environment even though PostgreSQL was locally healthy; repeat the full-stack checks on your assessment machine. No images have been pushed. Trivy scans, vulnerability counts, digests, screenshots, and Cosign keys have not been generated. Fill the table from your actual Trivy output; do not infer or copy results.

| Image | CRITICAL | HIGH | Image size |
| --- | ---: | ---: | ---: |
| `fest-backend:0.1` (before) | TBD | TBD | 1.61 GB (local build) |
| `fest-backend:0.2` (after) | TBD | TBD | 212 MB (local build) |

- Published `1.0.0` digest: TBD after your push.
- Steps not completed in this environment: verify Compose-backed database registration and persistence; perform Trivy scans; capture assessment screenshots; push versioned images; generate/sign/verify with your own Cosign key pair.

## Before starting

Install Docker Compose v2, Trivy, and Cosign on your machine, and authenticate to Docker Hub yourself. The assessment handout warns against Trivy versions `0.69.4`, `0.69.5`, and `0.69.6`; check `trivy --version` and use a trusted, unaffected release. Set the registration number in every terminal prompt so screenshots identify your work:

```sh
export PS1='[8047] \w $ '
```

Copy the example environment file and replace the sample password with a strong local value. Never commit `.env`, Docker Hub credentials, or `cosign.key`.

```sh
cp .env.example .env
```

## Stage 1: baseline backend

The initial Dockerfile installs requirements before copying `app.py` and uses Python 3.9. Build and inspect it:

```sh
docker build -f backend/Dockerfile -t fest-backend:0.1 backend
docker image ls fest-backend
docker run -d --name backend -p 8047:5000 -e REGNO=8047 fest-backend:0.1
docker ps
curl --fail http://localhost:8047/api/health
docker logs backend
docker rm -f backend
```

With no database configured, the health response should report `"database": false`. This temporary Stage 1 container uses the same host port as the later frontend, so remove it before starting Compose.

## Stage 2: three-tier Compose stack

```sh
docker compose config
docker compose up --build -d
docker compose ps
curl --fail http://localhost:8047/api/health
curl --fail http://localhost:8047/api/registrations
curl --fail -X POST http://localhost:8047/api/registrations \
  -H 'Content-Type: application/json' \
  -d '{"name":"Asha Example","event":"Hackathon"}'
curl --fail http://localhost:8047/api/registrations
```

Open `http://localhost:8047` and add two registrations through the page. Verify the frontend cannot resolve the database service (the frontend image may not include `ping`; use an available diagnostic container attached only to `frontend-net` if needed):

```sh
docker compose exec frontend ping -c 1 db
```

If the Nginx image has no `ping` binary, use a temporary diagnostic container attached only to the frontend network; the expected result is that `db` does not resolve:

```sh
docker run --rm --network 8047-docker-assessment_frontend-net \
  busybox:1.36 ping -c 1 -W 2 db
```

Persistence check:

```sh
docker compose down
docker compose up -d
curl --fail http://localhost:8047/api/registrations
docker volume ls
```

The PostgreSQL data is in the named volume `postgres_data`. `docker compose down -v` deletes it and all registrations.

## Stage 3: scan and harden

Build the hardened image separately as `fest-backend:0.2`; it uses a pinned Python 3.12 slim base, upgraded pinned Python dependencies, and a non-root UID. The Compose stack also uses this Dockerfile.

```sh
docker build -f backend/Dockerfile.hardened --build-arg APP_VERSION=0.2 \
  -t fest-backend:0.2 backend
./scripts/scan-image.sh fest-backend:0.1 before
./scripts/scan-image.sh fest-backend:0.2 after
./scripts/check-critical.sh fest-backend:0.2
```

The before/after reports are written to `reports/trivy-before.txt` and `reports/trivy-after.txt`. The critical-only check includes `--ignore-unfixed --exit-code 1` and exits nonzero when a fixable CRITICAL finding exists. Record the actual CRITICAL/HIGH totals and image sizes above. Results vary with the image build and vulnerability database; none are claimed in this README.

## Stage 4: version and publish

Build the fixed backend with its release version, tag both requested aliases, then push only when you are ready and authenticated:

```sh
docker build -f backend/Dockerfile.hardened --build-arg APP_VERSION=1.0.0 \
  -t devdeveloper4321/fest-backend:1.0.0 backend
docker tag devdeveloper4321/fest-backend:1.0.0 devdeveloper4321/fest-backend:1.0
docker push devdeveloper4321/fest-backend:1.0.0
docker push devdeveloper4321/fest-backend:1.0
```

Record the digest printed by the push and take your own Docker Hub Tags-page screenshot. After publishing, change the backend service in `compose.yaml` from `build:` to `image: devdeveloper4321/fest-backend:1.0.0` (keep its environment, networks, healthcheck, and other settings), then verify the registry image:

```sh
docker compose down
docker image rm fest-backend:0.2 devdeveloper4321/fest-backend:1.0.0
docker compose pull backend
docker compose up -d
curl --fail http://localhost:8047/api/health
curl --fail http://localhost:8047/api/registrations
```

The health response should show `version: 1.0.0`, and registrations should still exist in the named volume. This repository does not publish images or alter the Compose service to a not-yet-published image.

## Stage 5: Cosign

Generate a password-protected key pair on your own machine. The private key is ignored by Git; never share or commit it. The public key may be committed for assessment evidence.

```sh
cosign generate-key-pair
```

After the `1.0.0` tag has been pushed, sign and verify its immutable registry digest:

```sh
IMAGE=devdeveloper4321/fest-backend
DIGEST=$(docker buildx imagetools inspect "$IMAGE:1.0.0" | awk '/Digest:/ { print $2; exit }')
test -n "$DIGEST"
cosign sign --key cosign.key "$IMAGE@$DIGEST"
cosign verify --key cosign.pub "$IMAGE@$DIGEST"
```

For the unsigned-release check, build and push a distinct `1.0.1` image, and do not sign it. Then verify that Cosign rejects it:

```sh
docker build -f backend/Dockerfile.hardened --build-arg APP_VERSION=1.0.1 \
  -t devdeveloper4321/fest-backend:1.0.1 backend
docker push devdeveloper4321/fest-backend:1.0.1
./scripts/check-unsigned-rejected.sh devdeveloper4321/fest-backend:1.0.1 cosign.pub
```

## Screenshots and submission

Capture the whole terminal/browser window yourself, with the REGNO prompt and command visible in terminal evidence and the address bar/username visible where relevant. Keep original, unedited screenshots in `screenshots/`, named with the assessment evidence IDs. Do not use generated or other students' evidence. Commit stage progress as required by your assessment, then publish the GitHub repository yourself; this agent has not committed or pushed anything.