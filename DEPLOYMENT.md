# Deploying the evrardjp fork on Debian 13

This fork is deployed from source with
[XenOrchestraInstallerUpdater](https://github.com/ronivay/XenOrchestraInstallerUpdater).
The installer is pinned because its XO Proxy support modifies source code and is
part of the tested deployment contract.

This guide targets a dedicated Debian 13 amd64 VM. `xo-server` runs as root
because XO manages NFS/CIFS mounts, FUSE, loop devices, device mapper, and LVM.
Keep that privilege boundary inside the dedicated VM.

## Scope

The build includes xo-server, XO5, XO6, and all in-repository server plugins.
Source edition authorizes the locally implemented XO features. This fork also
enables XOSTOR without the XOA license service. The pinned installer authorizes
a source-built XO Proxy when one is installed later.

Vates-hosted updater, support, cloud, and catalog services are intentionally not
part of this deployment. VMware migration is also out of scope.

## Prepare Debian

Create a Debian 13 amd64 VM with at least 4 GiB RAM, 2 vCPUs, and sufficient
space for multiple complete source builds. Configure a static address or stable
DNS record, time synchronization, and outbound access for the initial source
build.

Install the basic tools needed to retrieve the installer:

```sh
apt-get update
apt-get install -y ca-certificates git
```

The installer installs Node.js 24, Yarn, Redis, build tools, and XO's native
runtime dependencies.

For development and CI outside the installer, `mise.toml` pins Node.js 24 and
Yarn 1.22.22. Run `mise install` only on a machine allowed to download those
tools; the deployment itself does not depend on mise.

## Pin and configure the installer

```sh
git clone https://github.com/ronivay/XenOrchestraInstallerUpdater.git
cd XenOrchestraInstallerUpdater
git checkout 3df17fde9134230445842654805644a45bbe8f45
cp sample.xo-install.cfg xo-install.cfg
```

Set these values in `xo-install.cfg`:

```sh
XOUSER="root"
PORT="8080"
INSTALLDIR="/opt/xo"

SELFUPGRADE="false"
CONFIGUPDATE="true"

REPOSITORY="https://github.com/evrardjp/xen-orchestra"
BRANCH="evrardjp-main"

PLUGINS="all"
AUTOUPDATE="true"
OS_CHECK="true"
ARCH_CHECK="true"
PRESERVE="3"
INSTALL_REPOS="true"
YARN_NETWORK_TIMEOUT="300000"
```

`BRANCH` also accepts a full commit SHA. Use the branch for the first install;
use an exact CI-approved SHA for subsequent promotions.

## Install

```sh
sudo ./xo-install.sh --install
```

The installer creates timestamped builds under `/opt/xo/xo-builds`, points
`/opt/xo/xo-server` at the active build, installs `xo-server.service`, and starts
Redis and XO.

Sign in at `http://<vm-address>:8080` with the initial credentials printed by
the installer and change the password immediately.

## Manage XO configuration

The installer initially writes `/root/.config/xo-server/config.toml`. After the
first installation, set this in `xo-install.cfg`:

```sh
CONFIGUPDATE="false"
```

`CONFIGUPDATE=true` replaces the user configuration on every update; it does
not merge new sample settings. New vendor defaults are already loaded from the
new build's `packages/xo-server/config.toml`. Keep the user configuration small
and limited to deployment-specific overrides.

Configure the public URL and reverse proxy in
`/root/.config/xo-server/config.toml`:

```toml
[http]
publicUrl = 'https://xo.example.net'
useForwardedHeaders = true

[[http.listen]]
port = 8080

[redis]
uri = 'redis://127.0.0.1:6379/0'
```

Prefer a trusted proxy address or CIDR instead of `true` when its address is
stable. The reverse proxy must support WebSocket upgrades for `/api/`.

Apply configuration changes with:

```sh
systemctl restart xo-server
journalctl -u xo-server -f
```

## Promote an update

Only deploy a commit that passed the upstream test suite and this fork's extra
tests. Set `BRANCH` to that full SHA, then run:

```sh
sudo ./xo-install.sh --update
```

Before promotion, review configuration changes between the deployed and
candidate revisions:

```sh
git diff <deployed-sha>..<candidate-sha> -- \
  packages/xo-server/config.toml \
  packages/xo-server/sample.config.toml
```

The installer preserves prior builds according to `PRESERVE`. To roll back:

```sh
sudo ./xo-install.sh --rollback
```

XO state is not stored in the release directory. Back up Redis,
`/var/lib/xo-server`, and `/root/.config/xo-server` independently.

## Weekly upstream synchronization

Keep `master` as an exact upstream mirror. Never merge upstream directly into
`evrardjp-main`:

```sh
git fetch upstream --prune --tags

git switch master
git merge --ff-only upstream/master
git push origin master

git switch evrardjp-main
git switch -c sync/upstream-YYYYMMDD
git merge upstream/master
```

Resolve conflicts on the temporary branch and open a pull request into
`evrardjp-main`. Never resolve conflicts by blindly selecting `ours` or
`theirs`. Preserve upstream behavior, then reapply the smallest source-edition
change. The following checks must pass before merge:

```sh
yarn --frozen-lockfile
yarn build
yarn test-unit
yarn test-lint
sudo yarn test-integration
bash scripts/check-xo-proxy-installer-patch.sh
```

The Proxy compatibility check protects the exact source hunk modified by the
pinned installer. If it fails, do not merge until the fork and installer update
strategy have been reviewed together. Enabling Git rerere locally can reuse
previous conflict resolutions without making them automatic:

```sh
git config rerere.enabled true
```

## XOSTOR

This fork exposes XOSTOR in source edition and skips XOA trial, bind, and unbind
operations. XOSTOR still requires compatible XCP-ng hosts, dedicated disks, the
host `updater.py` plugin, and reachable repositories providing the LINSTOR
packages. XOSTOR creation formats the selected disks; validate it first on a
disposable test pool.

Normal XCP-ng node updates are not XOA-entitlement restricted in source edition.
Each XCP-ng host downloads and verifies updates using its configured yum
repositories while XO orchestrates the operation.

## XO Proxy

XO Proxy is not needed on the main XO VM. It runs at a remote backup site to
move backup processing closer to hosts or storage. Deployment is deferred, but
the pinned installer patch is checked by CI.

When a separate Proxy VM is required, use the same pinned installer, repository,
and tested source SHA, then run:

```sh
sudo ./xo-install.sh --install --proxy
```

The installer patches Proxy license lookup, installs `xo-proxy.service`, and
prints JSON that can be imported into XO. Appliance update and support actions
remain unavailable for a source-built Proxy.

## Source notices

The Community registration banner is already inapplicable to source edition.
This fork also hides the Community banner and weekly modal by default while
retaining their implementation. Set `XO_SOURCE_NOTICES=true` in the XO5 build
environment to opt back in.
