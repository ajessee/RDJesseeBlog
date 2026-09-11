require 'open3'
require 'tmpdir'

class Recording < ApplicationRecord
  include MediaUploadValidation
  validate_media_upload :audio_file, types: MediaUploadValidation::AUDIO_TYPES, maximum: 200.megabytes
  class AudioConversionError < StandardError; end

  belongs_to :recorder, class_name: 'User', foreign_key: :user_id
  belongs_to :recordable, polymorphic: true
  has_one_attached :audio_file
  after_create_commit :process_audio!

  def process_audio!
    return unless audio_file.attached?
    return if audio_file.blob.content_type == 'audio/mp4'

    original = audio_file.blob
    Dir.mktmpdir('rdjessee-audio-') do |directory|
      output = File.join(directory, 'converted.m4a')
      original.open do |source|
        _stdout, _stderr, status = Open3.capture3(
          'ffmpeg', '-nostdin', '-hide_banner', '-loglevel', 'error',
          '-i', source.path, '-vn', '-c:a', 'aac', '-b:a', '192k', output
        )
        unless status.success? && File.size?(output)
          raise AudioConversionError, 'Audio conversion failed; the original attachment was retained'
        end
      end

      File.open(output, 'rb') do |file|
        audio_file.attach(io: file, filename: "#{original.filename.base}.m4a", content_type: 'audio/mp4')
      end
    end
  end
end
