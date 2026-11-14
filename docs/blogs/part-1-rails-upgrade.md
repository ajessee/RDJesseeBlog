# Six Rails Versions in One Sitting: Upgrading My Grandfather's Memorial Website

I run a small Rails app called RDJesseeBlog. It hosts over 170 stories my grandfather wrote late in life, along with pictures, guestbook comments, and audio recordings of family members reading his work aloud. It's not a high-traffic site. It's a family archive. But it had quietly drifted five years behind on Rails, and Ruby 3.0.0 was approaching end of life, so it was time to stop putting off the upgrade.

What I expected to be "bump some gem versions" turned into a full framework migration: Rails 6.1.3 to 8.1.3.1, Ruby 3.0.0 to 4.0.6, a new Docker-based development environment, a security review that found real problems, and a production incident on deploy day that took a bit of detective work to run down. Here's how it went.

## Why not just jump straight to the latest version

Rails doesn't support skipping major versions cleanly, and I didn't want to find that out the hard way in production. So the plan was to walk through every major version in sequence: 6.1 to 7.0 to 7.1 to 7.2 to 8.0 to 8.1, bumping Ruby only at compatible points along the way, and running the full test suite after every single step. Each version has its own "new framework defaults" file that documents behavior changes, and the temptation is to just bump the gem and ignore that file. I didn't, and it's a good thing I didn't; more on that below.

The very first roadblock showed up before I even got to the framework: the original Gemfile.lock referenced `mimemagic 0.3.5`, which had been pulled from RubyGems entirely due to a licensing issue years ago. The old lockfile couldn't install at all anymore. That's the kind of thing that makes you realize a five-year-old dependency tree isn't just "outdated," it's actively rotting.

## Building an isolated baseline before touching anything

Before changing a single line of application code, I set up a Docker Compose environment with its own Postgres, local file storage instead of production S3, and a mail adapter that doesn't actually send anything. The existing RSpec suite had 82 examples, with 25 failures and a lot of pending specs, several of them for helper modules that didn't even exist anymore. I cleaned those out and got a real, green baseline before starting the version climb: 107 examples, zero failures.

This mattered more than it might sound like. Every time a Rails upgrade broke something, I had a signal within seconds instead of finding out from a user that the pictures page was blank.

## The parts that actually broke

A few upgrades were uneventful. A few were not.

**Rich text.** The app used `trix-rails`, which is locked to Rails versions below 7 and has no forward-compatible release. Rather than migrate the existing story bodies into Action Text's attachment model (and risk mangling five years of formatted family stories in the process), I kept the plain-HTML database columns as-is and served a current npm-distributed version of Trix through Sprockets instead. Less "modern Rails way," more "don't touch what doesn't need touching."

**Pagination.** `will_paginate` 4.x changed its API in a way that broke the site's Bootstrap pagination renderer. Small fix, but the kind of thing that's invisible until you actually click "next page" during testing, which is exactly why I'd set up thorough manual and automated checks rather than trusting a green test suite alone.

**Cookies and sessions.** Rails 8.1 defaults to deriving cookie encryption keys with SHA-256 instead of SHA-1. That's a good change, but it meant every user who was logged in before the deploy would have had their session and their "remember me" cookie silently invalidated the moment the new code shipped, logging out anyone using the site at the time. Rails does support reading both formats during a transition period, so I wrote regression tests that construct cookies in both the old and new format and confirmed the app accepts both. Small detail, but the difference between "seamless upgrade" and "everyone gets logged out and wonders if the site broke."

**Authorization.** This is the one that actually worried me. While adding test coverage for every write action, I found a real gap: any signed-in reader, not just admins, could open the story creation form and publish a new story, even though the rest of the UI treated story management as admin-only. That's a privilege escalation bug that had presumably existed since 2020, just never exploited because nobody had reason to look for it. I closed it and then wrote request specs that explicitly check the anonymous, reader, owner, and admin boundary for every resource in the app: stories, users, comments, pictures, recordings, videos. I also found and fixed a couple of spots where record ownership was being read from a submitted form field instead of derived from the actual signed-in session, which is a classic way to let someone attach content to somebody else's account.

**Bot signups.** A production audit turned up 71 unverified accounts, all created in 2026, 8 of them in the last 30 days. Someone or something was hitting the signup form. After confirming none of those accounts owned any content, I added Cloudflare Turnstile (the free, privacy-respecting CAPTCHA alternative) with server-side validation that fails closed if it's misconfigured, and cleaned up the 63 stale accounts older than 30 days.

## The image pipeline, and a genuinely nasty security find

Rails 8.1 uses libvips for image processing by default. libvips is fast, but it can decode a long list of formats, several of which are backed by less battle-tested libraries. I explicitly called `Vips.block_untrusted(true)`, which restricts processing to libvips' hardened JPEG, PNG, GIF, and WebP loaders and disables the rest.

To prove this actually did something, I tested it with a file that had a `.jpeg` extension and claimed to be a JPEG, but was actually an OpenEXR image internally. Without content-based type checking, an app will happily trust the extension and hand the file to whatever decoder matches it. With content identification in place, the upload was correctly identified as unsupported and rejected outright, and even if it had gotten past that check, the untrusted-loader block would have refused to decode it. Belt and suspenders.

Running Docker Scout against the final production image surfaced 0 critical and 25 high-severity findings, concentrated in OpenEXR (installed transitively with libvips, and now unreachable since its loader is blocked), plus libvips, cJSON, libxml2, and zlib themselves, none of which have a published fix yet from Debian. Rather than either ignoring the scan or pretending the app is "fully patched," I wrote up an explicit, dated acceptance document: which findings are accepted, why, what mitigates them, and the exact conditions that expire the acceptance (a new critical finding, a published fix, or any regression in the blocked formats). A security posture that's honest about its residual risk is worth a lot more than a green checkmark that isn't quite true.

## The bug that only showed up after deploy

Everything above got tested, scanned, and verified before I touched production. And then, right after the release, every single picture on the site came back broken.

The cause turned out to be almost funny in hindsight: `db/schema.rb` had declared an `active_storage_variant_records` table since a Rails 6.1 upgrade back in 2021, but the migration file that was supposed to create it had never actually made it into the repository. Locally, this never mattered, because `db:schema:load` builds a fresh database straight from `schema.rb` and doesn't care whether a migration file exists for every table in it. Production, correctly, only runs `db:migrate`, which only applies migrations that actually exist. So the table had silently never been created in production, for five years, and nothing cared, because older Active Storage could serve image variants without persisting a record of them.

Rails 8.1 changed that. Its `ActiveStorage::VariantWithRecord` requires that table for every single image variant lookup. The moment the new code deployed, every image request turned into a `PG::UndefinedTable` error and a 500 response. I wrote the missing migration by hand (matching exactly what `schema.rb` already claimed the table looked like), deployed it, and ran it against production. Total downtime for images: about twenty minutes, all after I'd already gone through what I thought was a thorough release checklist.

The lesson: `schema.rb` describes what your database is supposed to look like if you trust the migration history that produced it. It is not proof that history is complete. If I do this kind of upgrade again, checking `bin/rails db:migrate:status` against every table `schema.rb` declares, on the actual production database, is now a permanent step before I call a migration done.

## What I'd tell someone about to do this

Upgrade in small steps and run the tests after each one; the version where something breaks tells you a lot about what actually changed. Don't let a green test suite be your only signal, since it can't catch a UI regression or a missing production migration. Read the "new framework defaults" changelog for every major version instead of assuming a gem bump adopts them automatically. Treat a security scan with unfixed findings as something to document and mitigate, not something to hide or wave away. And when you finally deploy, verify the actual behavior in production, not just that the release succeeded, because a release can succeed while a table that's been silently missing for five years turns your homepage into a wall of broken image icons.

The site's back up, faster than before, and running on a framework that'll be supported for years instead of one that was already deprecated. My grandfather's stories are safe, and so, for now, is everyone's login session.
