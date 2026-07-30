#!/usr/bin/env bash

set -euo pipefail

# Keep this synchronized with XenOrchestraInstallerUpdater commit
# 3df17fde9134230445842654805644a45bbe8f45. Its proxy installation
# applies this patch with --fuzz=0 after building the monorepo.
proxy_appliance="$(dirname "$0")/../@xen-orchestra/proxy/app/mixins/appliance.mjs"

patch --dry-run --fuzz=0 --no-backup-if-mismatch "$proxy_appliance" <<'PATCH'
--- appliance.mjs~	2022-03-30 15:28:52.360814994 +0300
+++ appliance.mjs	2022-03-30 15:27:57.823598169 +0300
@@ -153,10 +153,13 @@

   // A proxy can be bound to a unique license
   getSelfLicense() {
-    return Disposable.use(getUpdater(), async updater => {
-      const licenses = await updater.call('getSelfLicenses')
-      const now = Date.now()
-      return licenses.find(({ expires }) => expires === undefined || expires > now)
-    })
+  // modified by XenOrchestraInstallerUpdater
+  //
+  //  return Disposable.use(getUpdater(), async updater => {
+  //    const licenses = await updater.call('getSelfLicenses')
+  //    const now = Date.now()
+  //    return licenses.find(({ expires }) => expires === undefined || expires > now)
+  //  })
+    return true
   }
 }
PATCH
