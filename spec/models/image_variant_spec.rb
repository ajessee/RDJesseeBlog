require 'rails_helper'
require 'open3'

RSpec.describe 'Image variants' do
  it 'resizes and auto-orients through the Rails 8.1 libvips processor' do
    png, stderr, status = Open3.capture3('convert', '-size', '8x6', 'xc:white', 'png:-')
    raise stderr unless status.success?
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png), filename: 'sample.png', content_type: 'image/png')
    variant = blob.variant(resize_to_limit: [4, 4]).processed
    dimensions, _stderr, status = Open3.capture3('identify', '-format', '%wx%h', '-', stdin_data: variant.download, binmode: true)
    expect(status).to be_success
    expect(dimensions).to eq('4x3')
  end
end
