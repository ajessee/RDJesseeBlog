class Video < ApplicationRecord
  include MediaUploadValidation
  validate_media_upload :video_file, types: MediaUploadValidation::VIDEO_TYPES, maximum: 200.megabytes
  belongs_to :photographer, class_name: 'User', foreign_key: :user_id
  belongs_to :videoable, polymorphic: true
  has_many :comments, as: :commentable
  has_many :taggings
  has_many :tags, through: :taggings
  has_one_attached :video_file

  def set_success(format, opts)
    self.success = true
  end
  
end
