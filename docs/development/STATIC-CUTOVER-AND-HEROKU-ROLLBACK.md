# Static archive cutover and Heroku rollback

Updated November 13, 2026 after the production Pages release and `www` cutover. This runbook records the release and the DNS-only recovery path.

## Current checkpoint

- `www.ralphdonaldjessee.com` now points to Cloudflare Pages at `rdjessee-blog-preview.pages.dev` (TTL 1 hour). Cloudflare reports the custom domain Active with SSL enabled; public HTTPS checks return the converted site. The Heroku app and database remain available for rollback.
- The Cloudflare Pages project is `rdjessee-blog-preview` and uses direct uploads, with no Git integration. The production deployment is `https://13c81490.rdjessee-blog-preview.pages.dev/`; its configured production branch is `master`. The review preview is `https://codex-static-site-conversion.rdjessee-blog-preview.pages.dev/`.
- Both `preview.ralphdonaldjessee.com` and `www.ralphdonaldjessee.com` have active Cloudflare custom-domain associations with SSL enabled, and serve the converted archive.
- Squarespace manages DNS records; the authoritative nameservers are Google Cloud DNS. The apex redirect, nameservers, email records, and DNSSEC were not changed.
- The release source is merged into local `master` at `164f1e5` (`Build static archive conversion for Cloudflare Pages`); `master` is one commit ahead of `origin/master`. The untracked `BLOG-POST-DRAFT.md` was not uploaded. Check Git status before future release work.
- The static archive is read-only. The conversion does not include Rails sign-in, uploads, comments, or admin editing. Existing records are exported; new or corrected content would require a later owner-approved export and deployment.

## What the conversion changes

The Rails application currently runs on Heroku with PostgreSQL and S3-backed Active Storage. The static release exports public archive content from a local restored database, generates HTML, CSS, JavaScript, and JSON indexes, and uploads the generated files to Cloudflare Pages. Public media stays in the existing `andre-pictures` S3 bucket and is delivered through CloudFront with Origin Access Control. Direct S3 access remains blocked.

The exporter writes private data to `tmp/static-archive/export-cloudfront.json`; the builder writes the site to `dist/static-site/`. Both are ignored by Git. Only the generated site directory should be uploaded. Do not put database dumps, export JSON, credentials, or environment files in the Pages output.

The CloudFront distribution `E1KFB1NQNA9XY4` serves the 111 media objects in the reviewed manifest. The S3 bucket and objects are not being copied, renamed, or cleaned up as part of this release. Keep Heroku and its database available through the rollback window.

## Release procedure

The initial production release completed on November 13, 2026. Preserve the sequence below for future static releases; the `www` CNAME now points to Pages.

1. **Commit and inspect the source.** Review the conversion diff, remove unintended files, and commit the approved work on `codex/static-site-conversion`. Confirm the resulting branch and `master` relationship before merging. Do not merge unreviewed local changes.
2. **Capture a fresh database backup.** Confirm a recent Heroku PostgreSQL backup completed successfully. Preserve its identifier and verify the existing local restore is separate from the development database. If production content changed since the restore, restore the new backup locally before exporting.
3. **Export and build locally.** Use the repository commands in the README:

   ```sh
   npm run site:export
   npm run site:build
   npm run site:test
   ```

   Confirm the exporter reads the intended local archive database and that the output is `dist/static-site/`.
4. **Review the release artifact.** Confirm expected story, picture, recording, guestbook, and tag counts; review representative pages, navigation, filters, obituary carousel, and mobile layout. Verify that media URLs use the CloudFront hostname and that no database or private export file is in the output. Check internal routes and the media manifest. `npm run site:test` uses synthetic data and does not replace this content review.
5. **Deploy to a branch preview.** Upload with Wrangler to a non-production branch and review its branch-specific `pages.dev` URL. For example:

   ```sh
   npx wrangler pages deploy dist/static-site --project-name rdjessee-blog-preview --branch codex/static-site-conversion
   ```

6. **Promote to the Pages production branch.** Once the release artifact is approved, merge the reviewed source into `master`, then upload the same reviewed artifact using the production branch configured in the Cloudflare Pages dashboard (currently documented as `master`). Because this project uses direct uploads, merging alone does not publish the site. Confirm the resulting production `pages.dev` deployment and the associated `preview.ralphdonaldjessee.com` hostname show the converted site over HTTPS. Do not assume a branch-preview URL is the production deployment.
7. **Cut over only `www`.** In Squarespace DNS, change only the `www` CNAME from `www.ralphdonaldjessee.com.herokudns.com` to `rdjessee-blog-preview.pages.dev`, keeping the current TTL. Leave apex forwarding, nameservers, MX/SPF and other mail records, and DNSSEC unchanged.
8. **Verify from outside the dashboard.** Wait for DNS to resolve to Pages. Confirm Cloudflare reports `www.ralphdonaldjessee.com` Active with SSL enabled. Load the HTTPS homepage, representative story/picture/tag routes, a not-found route, CSS/JavaScript, and an audio range request. Inspect browser console/network errors. Keep Heroku available and monitor the public site during the rollback window.

For future releases, stop before changing DNS if a gate fails. DNS and certificate changes can take time to propagate; use the preview hostname and Pages deployment status to diagnose before another attempt.

## Roll back to Heroku

The intended first rollback is a DNS-only change. Since the application, database, and media remain on Heroku/S3, no database restore or S3 change should be needed for a simple static-site failure.

1. In Squarespace DNS, set the `www` CNAME back to the verified Heroku target `www.ralphdonaldjessee.com.herokudns.com` and retain the current TTL. Check the value in Heroku's custom-domain settings if it has changed since this runbook was updated.
2. Do not change the apex redirect, nameservers, email records, DNSSEC, S3 bucket policy, or CloudFront distribution during this rollback.
3. Wait for DNS caches to expire, then confirm public DNS resolves `www` to Heroku. Load `https://www.ralphdonaldjessee.com/`, `/up`, `/stories`, `/pictures`, and a representative story. Confirm Heroku ACM/TLS and application health before declaring rollback complete.
4. If Heroku is unhealthy, use the Heroku deployment record and release history to diagnose the last known-good app release. A DNS switch does not fix an unhealthy Heroku app. Avoid running migrations, `db:prepare`, or seeds as part of this DNS rollback.
5. Keep the Pages deployment and custom-domain association in place while diagnosing. Removing the Pages hostname is unnecessary for restoring Heroku and can make a later retry harder to interpret.

The `www` CNAME uses a one-hour TTL, but resolvers may cache records longer. During propagation, some visitors may reach Pages while others reach Heroku. Do not declare recovery based only on the DNS editor's saved state; check authoritative DNS, public resolvers, HTTPS, and the site itself.

## Rollback limits and retention

- Heroku remains the source of truth for application data until the cutover is accepted. The static site does not write to PostgreSQL and cannot accept new comments, uploads, sign-ins, or edits.
- If any content is changed directly in Heroku after the static export, that change will not appear in Pages. Export and redeploy an updated archive after review, or use Heroku as the live site again.
- Do not delete or scale down the Heroku app, PostgreSQL add-on, backups, S3 objects, CloudFront distribution, or Pages project during the rollback window. Confirm a separate backup/retention decision before decommissioning any paid service.
- The current production database backup/restore evidence and media-delivery design are recorded in [HOSTING-PLAN.md](HOSTING-PLAN.md) and the historical [Heroku deployment record](../archive/HEROKU-DEPLOYMENT.md).

## DNS change log

| Date | Host | Change | Result |
| --- | --- | --- | --- |
| November 13, 2026 | `www` | Changed CNAME from `www.ralphdonaldjessee.com.herokudns.com` to `rdjessee-blog-preview.pages.dev` in Squarespace | Cloudflare verified the domain, enabled SSL, and public HTTPS checks returned the converted site. Heroku remains available for rollback. |
| November 13, 2026 | `preview` | Added CNAME to `rdjessee-blog-preview.pages.dev` | Cloudflare domain became Active with SSL; converted site verified at `https://preview.ralphdonaldjessee.com/` |
