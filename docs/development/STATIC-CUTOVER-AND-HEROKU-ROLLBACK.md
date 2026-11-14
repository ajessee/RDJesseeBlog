# Static archive cutover and Heroku rollback

Updated November 14, 2026 after retiring the Heroku app. This runbook records the Pages release and the current recovery path.

## Current checkpoint

- `www.ralphdonaldjessee.com` points to Cloudflare Pages at `rdjessee-blog-preview.pages.dev` (TTL 1 hour). Cloudflare reports the custom domain Active with SSL enabled; public HTTPS checks return the converted site. The Heroku app and its add-ons were removed on November 14, 2026; this is no longer a DNS-only rollback.
- The Cloudflare Pages project is `rdjessee-blog-preview` and uses direct uploads, with no Git integration. The production deployment is `https://13c81490.rdjessee-blog-preview.pages.dev/`; its configured production branch is `master`. The review preview is `https://codex-static-site-conversion.rdjessee-blog-preview.pages.dev/`.
- Both `preview.ralphdonaldjessee.com` and `www.ralphdonaldjessee.com` have active Cloudflare custom-domain associations with SSL enabled, and serve the converted archive.
- Squarespace manages DNS records; the authoritative nameservers are Google Cloud DNS. The apex redirect, nameservers, email records, and DNSSEC were not changed.
- The conversion source is merged into local `master` at `164f1e5` (`Build static archive conversion for Cloudflare Pages`); `master` is one commit ahead of `origin/master`. Blog drafts are stored in `docs/blogs` and are not part of the Pages upload. Check Git status before future release work.
- The public Pages archive remains read-only: it does not include Rails sign-in, comments, uploads, or admin editing. Content changes are authored in the isolated local Rails database and exported to Pages by the owner-approved publishing workflow in [LOCAL-DEVELOPMENT.md](LOCAL-DEVELOPMENT.md). New media is uploaded to the existing S3 bucket and added to the CloudFront OAC allowlist; see [AWS-STATIC-MEDIA-PUBLISHING.md](AWS-STATIC-MEDIA-PUBLISHING.md).

## What the conversion changes

Before retirement, the Rails application ran on Heroku with PostgreSQL and S3-backed Active Storage. The static release exports public archive content from a local restored database, generates HTML, CSS, JavaScript, and JSON indexes, and uploads the generated files to Cloudflare Pages. Public media stays in the existing `andre-pictures` S3 bucket and is delivered through CloudFront with Origin Access Control. Direct S3 access remains blocked.

The exporter writes private data to `tmp/static-archive/export-cloudfront.json`; the builder writes the site to `dist/static-site/`. Both are ignored by Git. Only the generated site directory should be uploaded. Do not put database dumps, export JSON, credentials, or environment files in the Pages output.

The CloudFront distribution `E1KFB1NQNA9XY4` serves the 111 media objects in the reviewed manifest. The S3 bucket and objects were not copied, renamed, or cleaned up during Heroku retirement. The final Heroku database backup and restore details are in [HEROKU-REDEPLOY-AND-TEARDOWN.md](HEROKU-REDEPLOY-AND-TEARDOWN.md).

## Release procedure

The initial production release completed on November 13, 2026. Preserve the sequence below for future static releases; the `www` CNAME now points to Pages.

1. **Commit and inspect the source.** Review the source changes on the active work branch, remove unintended files, and merge reviewed changes into `master` when ready. Do not merge unreviewed local changes.
2. **Use the local authoring snapshot.** The Heroku database has been retired. Use `rdjessee_blog_authoring` and follow [LOCAL-DEVELOPMENT.md](LOCAL-DEVELOPMENT.md); do not expect to capture a new production database backup from Heroku. The verified last production snapshot is `b040`.
3. **Build and deploy a branch preview.** Run the repository publishing command against the isolated local authoring database:

   ```sh
   bin/publish-static-site preview
   ```

   It exports the authoring database, synchronizes only new media to the existing S3 bucket, verifies CloudFront access, builds `dist/static-site/`, and uploads the preview branch. Media synchronization requires the AWS role described in [AWS-STATIC-MEDIA-PUBLISHING.md](AWS-STATIC-MEDIA-PUBLISHING.md).
4. **Review the release artifact and preview.** Confirm expected story, picture, recording, guestbook, and tag counts; review representative pages, navigation, filters, obituary carousel, and mobile layout. Verify that media URLs use the CloudFront hostname and that no database or private export file is in the output. Check internal routes and the media manifest. `npm run site:test` uses synthetic data and does not replace this content review.
5. **Freeze the reviewed release.** If the authoring database or source changes after preview, repeat the preview and review. Otherwise keep the reviewed `dist/static-site/` output for production upload.

6. **Promote to the Pages production branch.** Once the release artifact is approved, merge the reviewed source into `master`, then upload the same reviewed artifact using the production branch configured in the Cloudflare Pages dashboard (currently documented as `master`):

   ```sh
   npx wrangler pages deploy dist/static-site --project-name rdjessee-blog-preview --branch master
   ```

   Merging alone does not publish the site. Confirm the resulting production `pages.dev` deployment and the associated `preview.ralphdonaldjessee.com` hostname show the converted site over HTTPS. Do not assume a branch-preview URL is the production deployment.
7. **Cut over only `www`.** In Squarespace DNS, change only the `www` CNAME from `www.ralphdonaldjessee.com.herokudns.com` to `rdjessee-blog-preview.pages.dev`, keeping the current TTL. Leave apex forwarding, nameservers, MX/SPF and other mail records, and DNSSEC unchanged.
8. **Verify from outside the dashboard.** Confirm Cloudflare reports `www.ralphdonaldjessee.com` Active with SSL enabled. Load the HTTPS homepage, representative story/picture/tag routes, a not-found route, CSS/JavaScript, and an audio range request. Inspect browser console/network errors. The Heroku rollback window ended with retirement; a return to Rails requires rebuilding the app as described below.

For future releases, stop before changing DNS if a gate fails. DNS and certificate changes can take time to propagate; use the preview hostname and Pages deployment status to diagnose before another attempt.

## Restore dynamic Rails service

The previous Heroku app, database add-on, and integrations were removed. A failure in the static site cannot be resolved by pointing DNS back to the old Heroku app. First rebuild and verify a Rails service using the recovery steps in [HEROKU-REDEPLOY-AND-TEARDOWN.md](HEROKU-REDEPLOY-AND-TEARDOWN.md), including restoring backup `b040` and provisioning replacement integrations. Keep Pages serving the site during that work. Only after the replacement Rails app is healthy and TLS is active should the `www` CNAME be changed to its new Heroku target. Leave apex forwarding, nameservers, email records, DNSSEC, S3, and CloudFront unchanged.

## Rollback limits and retention

- The static site does not write to PostgreSQL and cannot accept new comments, uploads, sign-ins, or edits. Content changes are authored in the local authoring database and published to Pages.
- The local authoring database is based on the final Heroku snapshot `b040`. It is not connected to a live production Rails database.
- Heroku has been retired. The local backup and the retained Pages release are recovery materials; restoring the dynamic Rails application requires rebuilding infrastructure.
- The current production database backup/restore evidence and media-delivery design are recorded in [HOSTING-PLAN.md](HOSTING-PLAN.md) and the historical [Heroku deployment record](../archive/HEROKU-DEPLOYMENT.md).

## DNS change log

| Date | Host | Change | Result |
| --- | --- | --- | --- |
| November 13, 2026 | `www` | Changed CNAME from `www.ralphdonaldjessee.com.herokudns.com` to `rdjessee-blog-preview.pages.dev` in Squarespace | Cloudflare verified the domain, enabled SSL, and public HTTPS checks returned the converted site. |
| November 13, 2026 | `preview` | Added CNAME to `rdjessee-blog-preview.pages.dev` | Cloudflare domain became Active with SSL; converted site verified at `https://preview.ralphdonaldjessee.com/` |
| November 14, 2026 | Heroku | Removed the `www` custom-domain attachment, scaled the dyno to zero, destroyed its three add-ons, and deleted the `rdjessee` app | Final backup `b040` restored and verified locally; public Pages homepage and story route returned HTTP 200. |
