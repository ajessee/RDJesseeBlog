require 'rails_helper'
require 'open3'

RSpec.describe 'Media upload validation' do
  it 'rejects active content uploaded as a picture' do
    picture = Picture.new
    picture.picture.attach(io: StringIO.new('<svg xmlns="http://www.w3.org/2000/svg"></svg>'), filename: 'active.svg', content_type: 'image/svg+xml')
    expect(picture).not_to be_valid
    expect(picture.errors[:picture]).to include('has an unsupported file type')
  end

  it 'rejects an EXR payload named and declared as JPEG' do
    exr, stderr, status = Open3.capture3('convert', '-size', '2x2', 'xc:black', 'exr:-')
    raise stderr unless status.success?

    picture = Picture.new
    picture.picture.attach(io: StringIO.new(exr), filename: 'disguised.jpg', content_type: 'image/jpeg')

    expect(picture.picture.blob.content_type).to eq('image/aces')
    expect(picture).not_to be_valid
    expect(picture.errors[:picture]).to include('has an unsupported file type')
  end

  it 'rejects empty audio' do
    recording = Recording.new
    recording.audio_file.attach(io: StringIO.new(''), filename: 'empty.wav', content_type: 'audio/wav')
    expect(recording).not_to be_valid
    expect(recording.errors[:audio_file]).to include('must not be empty')
  end

  it 'rejects oversized newly attached audio without allocating a large test file' do
    recording = Recording.new
    recording.audio_file.attach(io: StringIO.new('sample'), filename: 'sample.wav', content_type: 'audio/wav')
    recording.audio_file.blob.byte_size = 201.megabytes
    expect(recording).not_to be_valid
    expect(recording.errors[:audio_file]).to include('must be 200 MB or smaller')
  end
end
