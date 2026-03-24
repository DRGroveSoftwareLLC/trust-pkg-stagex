# trust-pkg-stagex

A [StageX](https://stagex.tools/)-based CA certificate trust package for
[cert-manager trust-manager](https://cert-manager.io/docs/trust/trust-manager/).
Uses CA certificates from `stagex/core-ca-certificates` instead of Debian's
`ca-certificates` package.

The image is built from scratch, contains no shell or package manager, and runs
as nonroot (UID 65532). All builds are reproducible and produce
[SLSA v1.2 Build Level 3](https://slsa.dev/spec/v1.2/) provenance attestations.

## Image contents

```
/ko-app/stagex-bundle-static                        # copier binary (entrypoint)
/stagex-package/cert-manager-package-stagex.json     # CA bundle JSON
```

The JSON file contains:

```json
{
  "name": "trust-pkg-stagex",
  "version": "<ca-certificates version>",
  "bundle": "<PEM-encoded CA certificates>"
}
```

## Building

Requires Docker with BuildKit.

```sh
make build
```

Override the version or image name:

```sh
make build VERSION=sx2026.03.0 IMAGE_NAME=ghcr.io/myorg/trust-pkg-stagex
```

Other targets:

```sh
make push       # build and push to registry
make scan       # build then run Trivy vulnerability scan
make clean      # remove local image
```

## Verifying provenance

Release images include SLSA v1.2 Build L3 provenance attestations. Verify with:

```sh
go install github.com/slsa-framework/slsa-verifier/v2/cli/slsa-verifier@v2.7.1

slsa-verifier verify-image \
  ghcr.io/drgrovesoftwarellc/trust-pkg-stagex@sha256:<digest> \
  --source-uri github.com/DRGroveSoftwareLLC/trust-pkg-stagex \
  --source-tag <version>
```

Or with Make:

```sh
make verify DIGEST=sha256:<digest> VERSION=sx2026.03.0
```

## Installing with trust-manager

### Helm values

Configure trust-manager to use this package instead of the default Debian one:

```yaml
defaultPackageImage:
  repository: ghcr.io/drgrovesoftwarellc/trust-pkg-stagex
  tag: "sx2026.03.0"
```

### trust-manager configuration

Because this image uses stagex-specific paths rather than the Debian defaults,
you also need to override the init container args and the default package
location.

In your trust-manager Helm values:

```yaml
app:
  trust:
    defaultPackage:
      args:
        - "/stagex-package"
        - "/packages"
  extraArgs:
    - "--default-package-location=/packages/cert-manager-package-stagex.json"
```

Or if deploying trust-manager manually, set the init container command to:

```yaml
args:
  - "/stagex-package"
  - "/packages"
```

And add to the trust-manager container args:

```
--default-package-location=/packages/cert-manager-package-stagex.json
```

### Bundle resource

Once trust-manager is configured, create a `Bundle` resource that uses the
default package:

```yaml
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: ca-certificates
spec:
  sources:
    - useDefaultCAs: true
  target:
    configMap:
      key: ca-certificates.crt
```

## Releasing

Tag a commit with the ca-certificates version:

```sh
git tag sx2026.03.0
git push origin sx2026.03.0
```

The release workflow builds the image, pushes to ghcr.io, generates SLSA
provenance, verifies it, and runs a vulnerability scan. The tag name becomes
the `VERSION` build arg directly.

## License

The copier binary entrypoint is sourced from
[cert-manager/trust-manager](https://github.com/cert-manager/trust-manager)
and licensed under [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0).
The CA certificates are derived from Mozilla's root program and licensed under
[MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/).
