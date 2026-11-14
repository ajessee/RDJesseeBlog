# AWS access for static media publishing

Updated November 13, 2026. New archive pictures and recordings stay in the existing `andre-pictures` bucket. The local publisher uploads only media referenced by the selected authoring database, then adds those exact S3 object ARNs to the existing CloudFront Origin Access Control (OAC) read allowlist. It does not make S3 objects public or delete existing objects.

## Current AWS identity

The AWS CLI profile `rdjessee-static-setup` assumes `arn:aws:iam::736773231048:role/RDJesseeStaticSiteSetup` from the authenticated IAM user profile `rdjessee-static-session`. The active CLI identity was verified as that assumed role on November 13, 2026. AWS CLI temporary credentials expire and can be refreshed with `aws login`; do not put access keys in the repository or `.env` files.

When the CLI login expires, run:

```sh
aws login --remote --profile rdjessee-static-session --region us-east-2
```

Open the printed URL in the built-in browser, sign in to AWS, copy the one-time verification code from the AWS page, and paste it into the waiting terminal. Verify the result before using the bucket:

```sh
aws sts get-caller-identity --profile rdjessee-static-setup
```

The expected ARN begins `arn:aws:sts::736773231048:assumed-role/RDJesseeStaticSiteSetup/`. Do not continue if the account or principal differs.

## Required upload permission

The role can list the bucket, read/update its bucket policy, and now has the inline policy `RDJesseeStaticMediaUpload`. It grants `s3:PutObject` only on [rdjessee-static-media-upload-policy.json](rdjessee-static-media-upload-policy.json), attached November 13, 2026. The AWS IAM policy simulator confirmed that a root-level 28-character key is allowed while a nested key is denied.

That statement permits only `s3:PutObject` on root-level 28-character keys, matching the current Active Storage key format. It grants no object reads, deletes, ACL changes, bucket-wide public access, or bucket-policy changes. Keep the existing `s3:ListBucket` and `s3:PutBucketPolicy` statements needed for inventory and the exact CloudFront allowlist update. Review the key format before changing Active Storage or expanding this resource pattern.

## Publishing flow

`bin/publish-static-site preview` and `bin/publish-static-site production` now:

1. Export the isolated `rdjessee_blog_authoring` database.
2. Use the AWS CLI profile to pass short-lived credentials to the Docker task without writing credentials to a file.
3. Compare referenced media keys to the existing bucket. Existing objects are reused; a key collision with a different size stops the publish rather than overwriting it.
4. Verify local blob size and Active Storage checksum, then upload only missing objects as private S3 objects with their content types.
5. Add exported keys to the existing CloudFront OAC statement's exact object-resource list, preserving every other bucket-policy statement and its account/distribution conditions.
6. Confirm each media URL returns the expected size through CloudFront, build the static site, and deploy it to the selected Pages branch.

The distribution `E1KFB1NQNA9XY4` has one S3 origin using OAC, no cache-behavior allowlist functions, and a bucket policy that grants `s3:GetObject` to CloudFront only for individually listed objects. The publisher does not change object ACLs, enable direct S3 access, modify the CloudFront distribution, or remove old allowlist entries. It never runs a bucket sync or deletion command.

Use the profile explicitly if needed:

```sh
AWS_PROFILE=rdjessee-static-setup bin/publish-static-site preview
AWS_PROFILE=rdjessee-static-setup bin/publish-static-site production
```

Do not run the production command until the preview has been reviewed. See [local authoring](LOCAL-DEVELOPMENT.md) for database refresh and edit steps. See [Heroku redeployment and teardown](HEROKU-REDEPLOY-AND-TEARDOWN.md) for the separate rollback and retirement plan.
