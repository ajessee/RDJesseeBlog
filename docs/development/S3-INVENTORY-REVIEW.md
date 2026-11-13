# S3 bucket inventory review

Initial read-only triage of the `andre-pictures` bucket, based on the production database restored locally and a complete S3 object inventory. No objects were deleted or changed.

## Inventory summary

The inventory has 792 objects. Of these, 111 are referenced by the public archive and are in the CloudFront allowlist; 112 are Rails image variants; 46 have Active Storage blob rows but no current attachment; and 523 have no matching Active Storage blob row. The 523 unmatched objects total 189,402,252 bytes (about 180.6 MiB).

| Unmatched key group | Objects | Size | Initial assessment |
| --- | ---: | ---: | --- |
| `rdjFeatures/` | 14 | 108.7 MiB | Large animated feature/demo GIFs dated May 2020. No current source reference found. Likely historical product documentation; inspect before cleanup. |
| `variants/` | 312 | 44.9 MiB | Rails-generated derivative files with no matching blob rows. Likely stale derivatives, but retain through the rollback window. |
| `uploads/` | 152 | 10.9 MiB | Legacy upload paths, including old story thumbnails and picture uploads. No current blob mapping; contents and legacy references need review. |
| Bucket root | 45 | 16.1 MiB | Mixed older photos, site assets, unidentified keys, and a 2018 SQL dump. `grandpaSigBlack.jpg` is still referenced by the repository README. Keep root items until references and backup purpose are checked. |

The other inventory classes are not cleanup candidates during conversion: 111 public archive attachments are required by the generated site; 112 Rails variants may still be needed while Rails remains live; 46 unattached blobs need investigation because they could represent pending or abandoned uploads; and 2 historical database dumps are held pending backup verification.

## Review artifacts

The mode-0600 artifacts under ignored `tmp/static-archive/` contain the complete per-object detail:

- `s3-cleanup-review.html` is an interactive, read-only review page.
- `s3-cleanup-review.csv` has each object's key, size, date, classification, and suggested action.
- `s3-bucket-inventory.csv` is the raw inventory export.

Initial triage does not establish that any unmatched object is safe to delete. Legacy URLs, external links, backup value, and the content of likely historical assets have not been fully checked. Defer deletions until after static cutover and the rollback window, then review candidates with the owner before removing them.
