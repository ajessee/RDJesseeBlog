require 'rails_helper'

RSpec.describe 'Association integrity' do
  it 'requires a story author' do
    story = Story.new(title: 'A memory', content: 'Something happened.')

    story.validate

    expect(story.errors.attribute_names).to include(:user)
  end

  it 'requires a comment author and parent' do
    comment = Comment.new(content: 'A memory')

    comment.validate

    expect(comment.errors.attribute_names).to include(:author, :commentable)
  end

  it 'requires a picture photographer and parent' do
    picture = Picture.new(caption: 'A photograph')

    picture.validate

    expect(picture.errors.attribute_names).to include(:photographer, :imageable)
  end

  it 'allows an unknown legacy recording owner but requires a parent' do
    recording = Recording.new(caption: 'A recording')

    recording.validate

    expect(recording.errors.attribute_names).not_to include(:recorder)
    expect(recording.errors.attribute_names).to include(:recordable)
  end

  it 'requires a video photographer and parent' do
    video = Video.new(caption: 'A video')

    video.validate

    expect(video.errors.attribute_names).to include(:photographer, :videoable)
  end

  it 'requires both sides of a tagging' do
    tagging = Tagging.new

    tagging.validate

    expect(tagging.errors.attribute_names).to include(:story, :tag)
  end
end
