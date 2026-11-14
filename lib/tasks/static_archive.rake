require 'cgi'
require 'base64'
require 'digest'
require 'fileutils'
require 'json'
require 'net/http'
require 'tempfile'
require 'uri'

namespace :static_archive do
  desc 'Export approved public archive data to a private JSON file for static-site generation'
  task export: :environment do
    output_path = Pathname.new(ENV.fetch('STATIC_ARCHIVE_EXPORT', Rails.root.join('tmp/static-archive/export-cloudfront.json').to_s))
    configured_media_base_url = ENV['STATIC_MEDIA_BASE_URL'].presence || 'https://d18adgc24rj7ak.cloudfront.net'

    clean_html = ->(value) { ActionController::Base.helpers.sanitize(value.to_s) }
    media_url_for_blob = lambda do |blob|
      media_base_url = configured_media_base_url
      next nil unless media_base_url

      encoded_key = URI::DEFAULT_PARSER.escape(blob.key, /[^A-Za-z0-9\-._~\/]/)
      "#{media_base_url.sub(%r{/+\z}, '')}/#{encoded_key}"
    end
    rewrite_embedded_media = lambda do |value|
      clean_html.call(value).gsub(%r{(?:https?://[^/\s"'<>]+)?/rails/active_storage/(?:blobs/(?:redirect|proxy)|representations/(?:redirect|proxy))/([^/\s"'<>]+)/[^\s"'<>]*}) do |stored_url|
        signed_blob_id = Regexp.last_match(1)
        blob = ActiveStorage::Blob.find_signed(signed_blob_id)
        blob ? (media_url_for_blob.call(blob) || stored_url) : stored_url
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        stored_url
      end
    end
    media_for = lambda do |record, attachment_name|
      attachment = record.public_send(attachment_name)
      next nil unless attachment.attached?

      blob = attachment.blob
      {
        url: media_url_for_blob.call(blob),
        filename: blob.filename.to_s,
        content_type: blob.content_type,
        byte_size: blob.byte_size
      }
    end

    users_by_id = User.select(:id, :name).index_by(&:id)
    stories = Story.includes(:tags, :recordings, :videos, :comments, picture_attachment: :blob).order(:title).map do |story|
      {
        id: story.id,
        title: clean_html.call(story.title),
        content_html: rewrite_embedded_media.call(story.content),
        year_written: story.year_written,
        decade: story.decade,
        location: story.location,
        genre: story.genre,
        category: story.category,
        life_stage: story.life_stage,
        word_count: story.word_count,
        author_name: users_by_id[story.user_id]&.name,
        tags: story.tags.map(&:name).sort,
        picture: media_for.call(story, :picture),
        recording_ids: story.recordings.map(&:id),
        video_ids: story.videos.map(&:id),
        comment_ids: story.comments.map(&:id)
      }
    end

    pictures = Picture.includes(:comments, picture_attachment: :blob).order(:created_at, :id).map do |picture|
      {
        id: picture.id,
        caption_html: rewrite_embedded_media.call(picture.caption),
        created_at: picture.created_at&.iso8601,
        photographer_name: users_by_id[picture.user_id]&.name,
        imageable_type: picture.imageable_type,
        imageable_id: picture.imageable_id,
        image: media_for.call(picture, :picture),
        comment_ids: picture.comments.map(&:id)
      }
    end

    recordings = Recording.includes(:audio_file_attachment, :recordable).order(:created_at, :id).map do |recording|
      {
        id: recording.id,
        caption_html: rewrite_embedded_media.call(recording.caption),
        created_at: recording.created_at&.iso8601,
        recordable_type: recording.recordable_type,
        recordable_id: recording.recordable_id,
        audio: media_for.call(recording, :audio_file)
      }
    end

    videos = Video.includes(:video_file_attachment, :videoable, :comments).order(:created_at, :id).map do |video|
      {
        id: video.id,
        caption_html: rewrite_embedded_media.call(video.caption),
        year: video.year,
        created_at: video.created_at&.iso8601,
        videoable_type: video.videoable_type,
        videoable_id: video.videoable_id,
        youtube_url: video.youtube_url,
        video: media_for.call(video, :video_file),
        comment_ids: video.comments.map(&:id)
      }
    end

    comments = Comment.includes(:author).order(:created_at, :id).map do |comment|
      {
        id: comment.id,
        content_html: rewrite_embedded_media.call(comment.content),
        created_at: comment.created_at&.iso8601,
        author_name: users_by_id[comment.user_id]&.name,
        commentable_type: comment.commentable_type,
        commentable_id: comment.commentable_id
      }
    end

    tags = Tag.includes(:stories).order(:name).map do |tag|
      { id: tag.id, name: tag.name, story_ids: tag.stories.map(&:id).sort }
    end

    unresolved_media_urls = (stories.map { |item| item[:content_html] } + pictures.map { |item| item[:caption_html] } + recordings.map { |item| item[:caption_html] } + videos.map { |item| item[:caption_html] } + comments.map { |item| item[:content_html] }).sum do |html|
      html.scan(%r{/rails/active_storage/}).length
    end
    media_references = stories.map { |item| item[:picture] } + pictures.map { |item| item[:image] } + recordings.map { |item| item[:audio] } + videos.map { |item| item[:video] }
    unmapped_media_references = media_references.count { |reference| reference && reference[:url].blank? }

    payload = {
      schema_version: 1,
      generated_at: Time.current.iso8601,
      source: 'RDJesseeBlog public archive export',
      unresolved_media_url_count: unresolved_media_urls,
      unmapped_media_reference_count: unmapped_media_references,
      stories: stories,
      pictures: pictures,
      recordings: recordings,
      videos: videos,
      comments: comments,
      tags: tags
    }

    FileUtils.mkdir_p(output_path.dirname, mode: 0o700)
    File.write(output_path, JSON.pretty_generate(payload), mode: 'w', perm: 0o600)
    File.chmod(0o600, output_path)
    puts "Exported #{stories.length} stories, #{pictures.length} pictures, #{recordings.length} recordings, #{videos.length} videos, #{comments.length} comments, and #{tags.length} tags to #{output_path}"
    puts 'The export contains public display fields only; it excludes account credentials and tokens.'
    puts 'Media URLs are references only. This task does not access, copy, or change S3 objects or permissions.'
    puts "WARNING: #{unresolved_media_urls} embedded Rails Active Storage URL(s) still need media mapping." if unresolved_media_urls.positive?
    puts "WARNING: #{unmapped_media_references} attached media item(s) have no stable URL." if unmapped_media_references.positive?
  end

  desc 'Switch the selected local authoring database to local Active Storage'
  task prepare_local_storage: :environment do
    abort 'This task only runs in development.' unless Rails.env.development?

    database_name = ActiveRecord::Base.connection_db_config.database
    abort "Refusing to change Active Storage on #{database_name}. Set DEVELOPMENT_DATABASE=rdjessee_blog_authoring." unless database_name == 'rdjessee_blog_authoring'

    updated = ActiveStorage::Blob.update_all(service_name: 'local')
    puts "Set #{updated} local authoring blob records to the local storage service."
  end

  desc 'Hydrate referenced authoring media from the public CloudFront distribution into local disk storage'
  task hydrate_media: :environment do
    abort 'This task only runs in development.' unless Rails.env.development?
    abort 'Select the isolated authoring database with DEVELOPMENT_DATABASE=rdjessee_blog_authoring.' unless ActiveRecord::Base.connection_db_config.database == 'rdjessee_blog_authoring'

    export_path = Pathname.new(ENV.fetch('STATIC_ARCHIVE_EXPORT', Rails.root.join('tmp/static-archive/export-cloudfront.json').to_s))
    abort "Missing #{export_path}; run static_archive:export first." unless export_path.file?

    archive = JSON.parse(export_path.read)
    references = archive.fetch('stories').map { |item| item['picture'] } +
      archive.fetch('pictures').map { |item| item['image'] } +
      archive.fetch('recordings').map { |item| item['audio'] } +
      archive.fetch('videos').map { |item| item['video'] }
    media_base = URI(ENV.fetch('STATIC_MEDIA_BASE_URL', 'https://d18adgc24rj7ak.cloudfront.net'))
    abort 'Media base URL must use HTTPS.' unless media_base.scheme == 'https'

    keys = references.compact.filter_map do |reference|
      next unless reference['url']

      uri = URI(reference.fetch('url'))
      abort "Unexpected media host #{uri.host}." unless uri.host == media_base.host && uri.scheme == 'https'

      URI::DEFAULT_PARSER.unescape(uri.path.delete_prefix('/'))
    end.uniq
    blobs_by_key = ActiveStorage::Blob.where(key: keys).index_by(&:key)
    missing_blobs = keys - blobs_by_key.keys
    abort "The selected authoring database is missing #{missing_blobs.length} referenced media blob(s)." if missing_blobs.any?

    hydrated = 0
    existing = 0
    keys.each do |key|
      blob = blobs_by_key.fetch(key)
      service = blob.service
      if service.exist?(key)
        existing += 1
        next
      end

      uri = URI.join("#{media_base}/", URI::DEFAULT_PARSER.escape(key, /[^A-Za-z0-9\-._~\/]/))
      bytes_written = 0
      Tempfile.create(['static-media-', File.extname(blob.filename.to_s)]) do |file|
        file.binmode
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 180) do |http|
          request = Net::HTTP::Get.new(uri.request_uri)
          http.request(request) do |response|
            abort "CloudFront returned HTTP #{response.code} for media key #{key}." unless response.is_a?(Net::HTTPSuccess)

            response.read_body do |chunk|
              file.write(chunk)
              bytes_written += chunk.bytesize
            end
          end
        end
        abort "Size mismatch for media key #{key}: downloaded #{bytes_written}, expected #{blob.byte_size}." unless bytes_written == blob.byte_size

        file.flush
        file.rewind
        local_checksum = Base64.strict_encode64(Digest::MD5.file(file.path).digest)
        abort "Checksum mismatch for media key #{key}." unless ActiveSupport::SecurityUtils.secure_compare(local_checksum, blob.checksum)

        file.rewind
        service.upload(key, file, checksum: blob.checksum)
      end
      hydrated += 1
    end

    puts "Local media ready: #{hydrated} downloaded and verified, #{existing} already present (#{keys.length} referenced objects)."
  end

  desc 'Upload referenced local authoring media and add exact keys to the CloudFront origin allowlist'
  task publish_media: :environment do
    abort 'This task only runs in development.' unless Rails.env.development?
    abort 'Select the isolated authoring database with DEVELOPMENT_DATABASE=rdjessee_blog_authoring.' unless ActiveRecord::Base.connection_db_config.database == 'rdjessee_blog_authoring'

    export_path = Pathname.new(ENV.fetch('STATIC_ARCHIVE_EXPORT', Rails.root.join('tmp/static-archive/export-cloudfront.json').to_s))
    abort "Missing #{export_path}; run static_archive:export first." unless export_path.file?

    require 'aws-sdk-s3'

    archive = JSON.parse(export_path.read)
    references = archive.fetch('stories').map { |item| item['picture'] } +
      archive.fetch('pictures').map { |item| item['image'] } +
      archive.fetch('recordings').map { |item| item['audio'] } +
      archive.fetch('videos').map { |item| item['video'] }
    abort 'The export contains attached media without a stable URL; refusing to publish.' if references.any? { |reference| reference && reference['url'].blank? }

    media_base = URI(ENV.fetch('STATIC_MEDIA_BASE_URL', 'https://d18adgc24rj7ak.cloudfront.net'))
    abort 'Media base URL must use HTTPS.' unless media_base.scheme == 'https'
    keys = references.compact.map do |reference|
      uri = URI(reference.fetch('url'))
      abort "Unexpected media host #{uri.host}." unless uri.host == media_base.host && uri.scheme == 'https'

      URI::DEFAULT_PARSER.unescape(uri.path.delete_prefix('/'))
    end.uniq

    blobs_by_key = ActiveStorage::Blob.where(key: keys).index_by(&:key)
    missing_blobs = keys - blobs_by_key.keys
    abort "The selected authoring database is missing #{missing_blobs.length} referenced media blob(s)." if missing_blobs.any?

    references.compact.each do |reference|
      key = URI::DEFAULT_PARSER.unescape(URI(reference.fetch('url')).path.delete_prefix('/'))
      blob = blobs_by_key.fetch(key)
      unless reference.fetch('byte_size') == blob.byte_size && reference.fetch('content_type') == blob.content_type
        abort "Export metadata no longer matches local blob #{key}; rerun static_archive:export."
      end
    end

    bucket = ENV.fetch('S3_BUCKET', 'andre-pictures')
    abort "Refusing to publish to unexpected bucket #{bucket}." unless bucket == 'andre-pictures'

    client = Aws::S3::Client.new(region: ENV.fetch('AWS_REGION', 'us-east-1'))
    remote_sizes = {}
    token = nil
    loop do
      response = client.list_objects_v2(bucket: bucket, continuation_token: token)
      response.contents.each { |object| remote_sizes[object.key] = object.size }
      break unless response.is_truncated

      token = response.next_continuation_token
    end

    missing_keys = keys.reject { |key| remote_sizes.key?(key) }
    invalid_new_keys = missing_keys.reject { |key| key.match?(/\A[a-z0-9]{28}\z/) }
    abort 'New media keys do not match the reviewed Active Storage key format; refusing to upload.' if invalid_new_keys.any?

    keys.each do |key|
      next unless remote_sizes.key?(key)

      expected_size = blobs_by_key.fetch(key).byte_size
      abort "S3 already contains #{key} with a different size; refusing to overwrite it." unless remote_sizes.fetch(key) == expected_size
    end

    # Validate every local file before the first remote write. Blob#open verifies
    # Active Storage's stored checksum while yielding the local file.
    missing_keys.each do |key|
      blobs_by_key.fetch(key).open do |file|
        abort "Local blob #{key} has the wrong size." unless file.size == blobs_by_key.fetch(key).byte_size
      end
    end

    uploaded = 0
    missing_keys.each do |key|
      blob = blobs_by_key.fetch(key)
      blob.open do |file|
        client.put_object(
          bucket: bucket,
          key: key,
          body: file,
          content_type: blob.content_type,
          content_length: blob.byte_size
        )
      end
      uploaded += 1
    end

    # The bucket policy intentionally grants CloudFront access to exact object
    # ARNs only. Extend that existing statement by unioning the exported keys;
    # retain every other policy statement and never grant direct public access.
    policy = JSON.parse(client.get_bucket_policy(bucket: bucket).policy)
    statement = policy.fetch('Statement').find { |item| item['Sid'] == 'AllowCloudFrontOACReadAllowlistedArchiveMedia' }
    abort 'The expected CloudFront origin access policy statement is missing; refusing to replace the bucket policy.' unless statement

    principal = statement['Principal']
    source_account = statement.dig('Condition', 'StringEquals', 'AWS:SourceAccount')
    source_arn = statement.dig('Condition', 'StringEquals', 'AWS:SourceArn')
    expected_distribution_arn = 'arn:aws:cloudfront::736773231048:distribution/E1KFB1NQNA9XY4'
    valid_oac_statement = statement['Effect'] == 'Allow' &&
      principal == { 'Service' => 'cloudfront.amazonaws.com' } &&
      statement['Action'] == 's3:GetObject' &&
      source_account == '736773231048' &&
      source_arn == expected_distribution_arn
    unless valid_oac_statement
      abort 'The existing CloudFront bucket-policy statement differs from the reviewed OAC policy; refusing to modify it.'
    end

    resources = statement['Resource']
    resources = [resources] unless resources.is_a?(Array)
    resources = resources.compact.uniq
    expected_arns = keys.map { |key| "arn:aws:s3:::#{bucket}/#{key}" }
    new_arns = expected_arns - resources
    unless new_arns.empty?
      statement['Resource'] = (resources + new_arns).sort
      client.put_bucket_policy(bucket: bucket, policy: JSON.generate(policy))
    end

    puts "Media publish ready: #{uploaded} new object(s) uploaded, #{keys.length - uploaded} existing object(s) reused, #{new_arns.length} exact CloudFront allowlist entry/entries added."
  end

  desc 'Confirm all exported media objects can be read through CloudFront before static publishing'
  task verify_media_published: :environment do
    abort 'This task only runs in development.' unless Rails.env.development?
    abort 'Select the isolated authoring database with DEVELOPMENT_DATABASE=rdjessee_blog_authoring.' unless ActiveRecord::Base.connection_db_config.database == 'rdjessee_blog_authoring'

    export_path = Pathname.new(ENV.fetch('STATIC_ARCHIVE_EXPORT', Rails.root.join('tmp/static-archive/export-cloudfront.json').to_s))
    abort "Missing #{export_path}; run static_archive:export first." unless export_path.file?

    archive = JSON.parse(export_path.read)
    references = archive.fetch('stories').map { |item| item['picture'] } +
      archive.fetch('pictures').map { |item| item['image'] } +
      archive.fetch('recordings').map { |item| item['audio'] } +
      archive.fetch('videos').map { |item| item['video'] }
    media_base = URI(ENV.fetch('STATIC_MEDIA_BASE_URL', 'https://d18adgc24rj7ak.cloudfront.net'))
    abort 'Media base URL must use HTTPS.' unless media_base.scheme == 'https'

    failures = []
    references.compact.uniq { |reference| reference['url'] }.each do |reference|
      uri = URI(reference.fetch('url'))
      abort "Unexpected media host #{uri.host}." unless uri.host == media_base.host && uri.scheme == 'https'

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
        http.request(Net::HTTP::Head.new(uri.request_uri))
      end
      failures << URI::DEFAULT_PARSER.unescape(uri.path.delete_prefix('/')) unless response.is_a?(Net::HTTPSuccess) && response['content-length'].to_i == reference.fetch('byte_size')
    rescue StandardError => error
      failures << "#{reference['filename']} (#{error.class})"
    end

    if failures.any?
      abort "#{failures.length} media object(s) are unavailable or have the wrong size through CloudFront; upload them to the existing bucket and update its exact CloudFront allowlist before publishing."
    end

    puts "Verified #{references.compact.uniq { |reference| reference['url'] }.length} media objects through CloudFront."
  end
end
