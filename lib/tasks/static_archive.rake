require 'cgi'
require 'fileutils'
require 'json'
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
end
