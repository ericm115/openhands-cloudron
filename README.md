# OpenHands Cloudron Community App

Cloudron packaging for OpenHands Agent Canvas. The package wraps the official Agent Canvas image and adapts persistence, permissions, and startup for Cloudron.

## Install

Add this URL under **Cloudron Dashboard → App Store → Add custom app**:

```text
https://raw.githubusercontent.com/ericm115/openhands-cloudron/main/CloudronVersions.json
```

CLI installation:

```bash
cloudron install --versions-url https://raw.githubusercontent.com/ericm115/openhands-cloudron/main/CloudronVersions.json
```

## Architecture

- `Dockerfile.cloudron` inherits from the official `ghcr.io/openhands/agent-canvas` image.
- `start.sh` creates persistent directories as root, repairs ownership, then starts OpenHands as the upstream `openhands` user with `runuser`.
- Cloudron exposes HTTP port `8000`.
- OpenHands Canvas is mounted at `/canvas`.
- Persistent state is stored under `/app/data` through the `localstorage` addon.
- Telemetry is disabled with `VITE_DO_NOT_TRACK=1`.

Persistent paths:

```text
/app/data/openhands   OpenHands settings, keys, conversations, and automation DB
/app/data/workspaces  Automation workspaces
/app/data/storage     Automation file storage
```

Nested Docker is not supported. Use an external Agent Server when workloads require Docker-based isolation.

## Prerequisites

- Docker with an authenticated Docker Hub session
- GitHub CLI authenticated to the package repository
- Current Cloudron CLI

```bash
npm install --global cloudron@latest
cloudron --version
docker login
gh auth status
```

## Version model

Two versions are maintained independently:

- **Upstream version**: official Agent Canvas image in `Dockerfile.cloudron`.
- **Package version**: Cloudron package version in `CloudronManifest.json`, `CloudronVersions.json`, Docker Hub tag, and `CHANGELOG`.

Packaging-only fixes increment the package patch version without changing the upstream image. An upstream upgrade changes the `FROM` image and increments the package version.

Keep the packager display name generic. Never add a personal full name.

## Build and test

Set the package version once in your shell:

```bash
PACKAGE_VERSION=1.16.2
```

Build:

```bash
docker build -f Dockerfile.cloudron -t emoralesjw/openhands-cloudron:$PACKAGE_VERSION .
```

Run a local smoke test:

```bash
rm -rf .tmp-cloudron-data
mkdir -p .tmp-cloudron-data

docker run --rm \
  --name openhands-cloudron-test \
  -p 18080:8000 \
  -v "$PWD/.tmp-cloudron-data:/app/data" \
  -e LOCAL_BACKEND_API_KEY=test-key \
  -e OH_SECRET_KEY=test-secret \
  emoralesjw/openhands-cloudron:$PACKAGE_VERSION
```

In another terminal:

```bash
curl --fail --retry 30 --retry-delay 4 http://localhost:18080/
curl --fail http://localhost:18080/server_info
```

Verify persisted paths and ownership:

```bash
docker exec openhands-cloudron-test sh -c 'id; find /app/data -maxdepth 2 -printf "%u:%g %p\n"'
```

Expected results:

- Port `8000` becomes reachable.
- Logs contain `All services started`.
- No `Permission denied`, `not found`, traceback, or restart loop appears.
- `/app/data` content is owned by `openhands` inside the container.

## Cloudron metadata validation

Validate the catalog with a current CLI:

```bash
cloudron versions list
```

Verify public assets:

```bash
curl --fail --head https://assets.openhands.dev/logo-whitebackground.png
curl --fail --head https://assets.openhands.dev/screenshot/automation-preview.png
```

Current community-app constraints:

- `CloudronVersions.json` embeds the complete release manifest.
- `packageUrl` requires `minBoxVersion` of at least `10.0.0`.
- `iconUrl`, `packagerName`, and `packagerUrl` require at least `9.1.0` and are required for community apps.
- `mediaLinks` must be non-empty public HTTPS URLs.
- The catalog version key must equal `manifest.version`.
- `dockerImage` must reference a published registry image.
- JSON files must be UTF-8 without a byte-order mark.

## Publish a release

1. Update the upstream image in `Dockerfile.cloudron` when applicable.
2. Choose a new package semver; never mutate an already published version.
3. Update:
   - `CloudronManifest.json` → `version`
   - `CloudronVersions.json` → version key, embedded `manifest.version`, `dockerImage`, `creationDate`, `ts`, and `changelog`
   - `CHANGELOG`
4. Build and complete the local smoke test.
5. Push the image:

```bash
docker push emoralesjw/openhands-cloudron:$PACKAGE_VERSION
```

6. Validate:

```bash
cloudron versions list
docker manifest inspect emoralesjw/openhands-cloudron:$PACKAGE_VERSION
```

7. Commit and push only after image and catalog validation:

```bash
git add Dockerfile.cloudron start.sh CloudronManifest.json CloudronVersions.json CHANGELOG README.md
git commit -m "Release Cloudron package $PACKAGE_VERSION"
git push
```

8. Confirm the public catalog contains the new version:

```bash
curl --fail https://raw.githubusercontent.com/ericm115/openhands-cloudron/main/CloudronVersions.json
```

## Logs and troubleshooting

Follow app logs:

```bash
cloudron logs --app <app-id-or-location> --tail
```

Retrieve recent logs:

```bash
cloudron logs --app <app-id-or-location> --lines 1000
```

Export structured logs:

```bash
cloudron logs --app <app-id-or-location> --lines 1000 --ndjson > cloudron-app.log
```

Inspect status and container files:

```bash
cloudron status --app <app-id-or-location>
cloudron exec --app <app-id-or-location> -- id
cloudron exec --app <app-id-or-location> -- ls -la /app/data
```

Search downloaded logs first for:

```bash
grep -Ei 'permission denied|not found|traceback|error|failed|exited|healthcheck' cloudron-app.log
```

Common failures:

### `Permission denied` under `/app/data`

Cloudron replaces image-time `/app/data` with its persistent volume. Image-time ownership does not survive that mount. `start.sh` must run as root, create directories, run `chown -R openhands:openhands /app/data`, and only then drop privileges.

### `exec: ...: not found`

Never assume Cloudron base-image utilities exist in the upstream image. Verify the exact command first:

```bash
docker run --rm --entrypoint sh ghcr.io/openhands/agent-canvas:<version> -c 'command -v runuser'
```

The current upstream image provides `/usr/sbin/runuser` but not `gosu`.

### Health check connection refused

Find the first container error before the health-check messages. Repeated health failures are usually a consequence of the entrypoint exiting before port `8000` opens.

### Catalog changes are not visible

Confirm the raw catalog, then use a temporary query parameter to bypass intermediary caches:

```text
https://raw.githubusercontent.com/ericm115/openhands-cloudron/main/CloudronVersions.json?version=<package-version>
```

## Release checklist

- [ ] Upstream image tag exists.
- [ ] Package version is new and synchronized everywhere.
- [ ] Generic packager display name retained.
- [ ] Docker image builds.
- [ ] Mounted `/app/data` smoke test passes.
- [ ] HTTP health endpoint responds.
- [ ] No startup errors appear in logs.
- [ ] `cloudron versions list` succeeds.
- [ ] Docker image is pushed before catalog publication.
- [ ] Docker manifest is remotely visible.
- [ ] Public catalog shows the new version and image.
- [ ] Package source is committed and pushed.
