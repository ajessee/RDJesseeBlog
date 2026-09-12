# Container security acceptance

Updated September 12, 2026. This is a narrow, temporary acceptance for the current Rails upgrade candidate; it is not a claim that the image has no vulnerabilities.

## Current evidence

Docker Scout's focused refresh of `rdjessee-production:local` (`sha256:ccd1a5f54812`, Linux ARM64, 742 indexed packages) reports 0 critical and 25 high findings in six packages:

The mitigated image was then rebuilt as `sha256:1fb020ffb52b`. Its final non-root runtime (UID 1000) boots Rails 8.1.3.1 with libvips 8.16.1, loads all four accepted image formats, and blocks OpenEXR. The rebuild reused the scanned system and gem installation layers and changed application/assets layers. A new Docker Scout upload was not authorized because it transmits SBOM metadata externally, so the 25-finding report remains the package baseline rather than a claimed scan of the new digest. The user later authorized a direct Heroku buildpack deployment while skipping staging; production `v169` therefore does not satisfy an exact Docker-image scan gate and must not be described as though it does. Obtain explicit approval before any future external SBOM upload.

| Package | High findings | Application exposure |
| --- | ---: | --- |
| OpenEXR | 15 | Installed transitively with libvips. EXR is not an accepted upload type, content identification rejects a disguised EXR, and libvips untrusted-operation blocking now disables its loader. |
| libvips | 3 | Used for variants of authenticated JPEG, PNG, GIF, and WebP uploads. Still reachable and therefore residual risk. |
| cJSON | 3 | Installed through media dependencies. Potentially reachable while ffmpeg processes authenticated audio/video uploads. |
| libxml2 | 2 | Transitively installed. Less-hardened libvips loaders are blocked, but transitive runtime use cannot be ruled out. |
| zlib | 1 | Used by accepted PNG processing and therefore reachable. |
| Ruby default `json` 2.18.0 | 1 | Inactive default-gem copy in the base image. `bundle exec` loads the application's locked JSON 2.21.2, which is newer than the reported fixed 2.19.2. |

No Debian fix is published for the 24 OS-package findings in this image. The scanner count does not fall when a vulnerable decoder is disabled because the package remains installed.

## Mitigations and limits

- `Vips.block_untrusted(true)` is applied when Rails boots, following libvips' guidance for untrusted images. A regression proves OpenEXR decoding is unavailable while JPEG, PNG, GIF, and WebP remain usable.
- Uploads are content-identified and limited to explicit MIME allowlists and sizes: 20 MB for images and 200 MB for audio/video.
- Image and media writes require an authenticated, activated account; story images require an administrator. This reduces anonymous reachability but does not make uploaded content trusted.
- The production image excludes ImageMagick, runs as a non-root user, and invokes ffmpeg without shell interpolation. Conversion failures retain the original for controlled retry.
- Processing is still synchronous and is not sandboxed. Crafted accepted images, audio, or video could still target a trusted decoder or cause resource exhaustion.

## Decision and expiry

Temporarily accept the residual 0-critical/25-high package report for a controlled staging candidate and, if all release checks pass, the first Rails 8.1 production rollout. This is justified by the lack of published package fixes, blocked OpenEXR/other untrusted loaders, authenticated upload boundary, size limits, non-root runtime, and the need to preserve existing media behavior.

The acceptance expires immediately if any critical finding appears, a fix becomes available, accepted formats fail their regression, an upload bypass is found, or the application begins accepting anonymous media. Refresh the image and scan immediately before deployment and at every subsequent dependency/base-image update. Do not suppress findings from output. Moving conversions to a constrained background worker remains a separate reliability and defense-in-depth improvement.

Sources: [libvips security checklist](https://github.com/libvips/libvips/blob/master/doc/developer-checklist.md), [libvips untrusted-operation guidance](https://github.com/libvips/libvips/discussions/3705), and [ruby-vips blocking API](https://github.com/libvips/ruby-vips/blob/master/CHANGELOG.md).
