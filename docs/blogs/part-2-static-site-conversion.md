# Turning a Rails App Into a Static Family Archive: Part Two

In [Part One](part-1-rails-upgrade.md), I wrote about bringing my grandfather's memorial website from Rails 6.1 and Ruby 3 up to current versions. That work made the app safer and easier to maintain. It also made me ask a bigger question: did this archive still need to run as a full Rails application?

The site holds my grandfather Ralph Donald Jessee's stories, family pictures, recordings of relatives reading his work, and guestbook messages. By the time the Rails upgrade was finished, the answer seemed clear. The archive was valuable, but it had become mostly read-only. We weren't adding new stories, comments, or recordings. Paying every month to keep a web server and database running around the clock no longer matched how the site was being used.

## A Rails app for a site that rarely changes

Rails had served the archive well. It provided the database, admin screens, search, account system, and the pages visitors read. But most visitors came to read a story or look at a picture. They weren't signing in or creating new content, and the site wasn't receiving new guestbook comments or recordings.

Before the conversion, the Heroku app used a Basic web dyno and an Essential-0 Postgres database. Together those were about $12 a month at the listed base rates, before taxes or other account charges. That is not an enormous bill, but it is a recurring cost for infrastructure that was spending most of its time waiting for a page request.

The goal became simple: keep the archive online and easy to read, while stopping the Rails app and database from running continuously.

## What static hosting means here

The new public site is still made from the same archive data, but Rails no longer renders each page when someone visits. Instead, Rails runs locally against a private copy of the production database. A task exports the public stories and other display data, and a generator turns that export into HTML, CSS, JavaScript, and search/filter data. The generated files are uploaded directly to Cloudflare Pages.

The current archive contains 193 stories, 56 pictures, 39 recordings, 23 guestbook comments, and 97 tags. The static generator creates pages for the archive and its stories, pictures, and tags. The homepage keeps the original sections and behaviors, including the typed hero passage, random story and picture selections, parallax quotes, filters, audio players, and obituary carousel.

JavaScript still runs in the browser for those interactive pieces. Static describes how the pages are delivered: visitors receive ready-made files rather than asking a Rails server to build a response for each request.

## We kept the media in S3

The largest part of the site is its media. One audio recording alone is over 124 MiB, so copying the media into another hosting service would have created duplicate storage and another place to manage files.

Instead, the pictures and recordings remain in the existing S3 bucket. CloudFront delivers them to visitors, and its origin access control lets the distribution read only the reviewed media objects. The bucket itself does not need to be public. Cloudflare Pages serves the generated pages; CloudFront continues serving the images and audio.

That split keeps the site files separate from the media library and avoids copying the archive to a second bucket. S3 and CloudFront still have their own storage and delivery costs, so the conversion reduces the always-on application hosting cost rather than making hosting entirely free.

## The tradeoff: visitors can read, but not contribute

The biggest change is that the public site no longer has Rails sign-in, admin editing, comment submission, or media uploads. The existing guestbook messages remain visible, but visitors cannot add new ones through the static site. That fits the way the site is being used today, but it is a real loss if the family wants those features back later.

For new content, I can run the Rails app locally against a separate authoring database restored from the latest Heroku backup. The app keeps uploads on local disk. When content is ready, the publishing workflow exports the local database and rebuilds the Pages site. Existing media can continue using the current CloudFront URLs; newly added media needs to be uploaded to the existing S3 bucket and allowed through the CloudFront policy before the new site can use it.

This workflow means a story edit does not require a Heroku deployment. It does mean publishing is a deliberate build-and-upload step, and visitor submissions are not part of the public experience. We can reconsider a small CMS or submission service if the archive starts changing regularly again.

## Moving carefully, then retiring Heroku

The conversion was not a blind export. I compared the generated site with the original, checked the story routes and media references, reviewed the production Pages deployment, and kept the original media bucket in place. Before retiring Heroku, I captured a fresh database backup and restored it into the isolated local authoring database. The final snapshot contains the archive records needed to regenerate the static site.

Once the static site was serving the public domain, I removed the Heroku custom-domain attachment, stopped the web dyno, removed its database and add-ons, and deleted the app. The Pages site continued serving the homepage and stories afterward. The other Heroku apps in the account were left alone.

Removing Heroku means returning to Rails would take more work than changing DNS back. The recovery path is documented, and the final database dump is stored privately outside Git. To bring Rails back, I would need to create a new app and database, restore that dump, recreate any required integrations, and verify the replacement before pointing the domain at it.

## What changed, and what didn't

The site still preserves the stories, pictures, recordings, and guestbook entries people came to see. The visitor-facing archive is generated locally and hosted on Pages. The existing S3 and CloudFront media delivery remains in place. What went away is the always-running Rails server and database, along with the ability for visitors to sign in or add content.

For an archive that is mostly read and only occasionally updated, that feels like a better fit. It lowers recurring application hosting costs and removes a server we no longer need to keep running, while leaving a clear path to update the site locally or rebuild the Rails service if its role changes in the future.
