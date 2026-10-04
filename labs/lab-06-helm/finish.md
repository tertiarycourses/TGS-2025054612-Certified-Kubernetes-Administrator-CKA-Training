# Well done!

You have completed Lab 6 — Install Components with Helm:

✅ Installed Helm 3 and added a chart repository
✅ Read `helm show values` before overriding anything
✅ Installed release `web` and saw `ui.message` in the app's own `/api/info`
✅ Upgraded with a values file to revision 2, then rolled back to revision 1
✅ Confirmed Helm keeps each revision in a `sh.helm.release.v1.*` Secret
✅ Rendered YAML with `helm template` without creating anything
✅ Diagnosed a retired repository: `helm pull bitnami/nginx` → 403, and the chart's image
   tag → 404, the real cause of `ImagePullBackOff`

**Next:** Lab 7 — Customize Manifests with Kustomize
