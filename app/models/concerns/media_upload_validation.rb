module MediaUploadValidation
  extend ActiveSupport::Concern

  IMAGE_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze
  AUDIO_TYPES = %w[audio/mpeg audio/mp3 audio/mp4 audio/x-m4a video/mp4 audio/wav audio/x-wav audio/ogg application/ogg audio/webm video/webm audio/flac audio/x-flac].freeze
  VIDEO_TYPES = %w[video/mp4 video/webm video/quicktime].freeze

  class_methods do
    def validate_media_upload(name, types:, maximum:)
      validate do
        next unless attachment_changes.key?(name.to_s)
        attachment = public_send(name)
        next unless attachment.attached?
        blob = attachment.blob
        errors.add(name, 'must not be empty') if blob.byte_size.zero?
        errors.add(name, "must be #{maximum / 1.megabyte} MB or smaller") if blob.byte_size > maximum
        errors.add(name, 'has an unsupported file type') unless types.include?(blob.content_type)
      end
    end
  end
end
