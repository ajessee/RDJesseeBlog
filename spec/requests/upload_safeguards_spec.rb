require 'rails_helper'
require 'open3'
require 'tempfile'

RSpec.describe 'Upload safeguards', type: :request do
  let(:user) { FactoryBot.create(:user, activated: true) }

  before do
    post login_path, params: { session: { email: user.email, password: 'password' } }
  end

  def audio_upload
    Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/sample.wav'), 'audio/wav')
  end

  def with_browser_audio_upload
    bytes, stderr, status = Open3.capture3(
      'ffmpeg', '-nostdin', '-hide_banner', '-loglevel', 'error',
      '-f', 'lavfi', '-i', 'sine=frequency=440:duration=0.1',
      '-c:a', 'libopus', '-f', 'webm', 'pipe:1'
    )
    raise stderr unless status.success?

    Tempfile.create(['browser-recording', '.webm']) do |file|
      file.binmode
      file.write(bytes)
      file.flush
      yield Rack::Test::UploadedFile.new(file.path, 'audio/webm', true,
                                         original_filename: 'recording.webm')
    end
  end

  it 'returns a useful JSON error for a missing audio file without creating a record' do
    expect { post recordings_path, params: { recording: { caption: 'Memory' } }, as: :json }.not_to change(Recording, :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']).to include('must be selected')
  end

  it 'renders the upload form for an invalid HTML submission' do
    post recordings_path, params: { recording: { caption: 'Memory' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('must be selected', 'Upload Audio')
  end

  it 'returns the destination after a successful AJAX audio upload' do
    post recordings_path, params: { recording: { caption: 'Memory', audio_file: audio_upload } }, headers: { 'ACCEPT' => 'application/json' }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['redirect_url']).to eq(recordings_path)
    expect(Recording.last.audio_file.blob.content_type).to eq('audio/mp4')
  end

  it 'accepts and converts browser-style WebM/Opus microphone audio' do
    with_browser_audio_upload do |upload|
      post recordings_path,
           params: { recording: { caption: 'Browser memory', audio_file: upload } },
           headers: { 'ACCEPT' => 'application/json' }
    end

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['redirect_url']).to eq(recordings_path)
    recording = Recording.last
    expect(recording.caption).to eq('Browser memory')
    expect(recording.audio_file.blob.content_type).to eq('audio/mp4')
    recording.audio_file.blob.open do |file|
      stdout, _stderr, status = Open3.capture3(
        'ffprobe', '-v', 'error', '-show_entries', 'stream=codec_name',
        '-of', 'default=noprint_wrappers=1', file.path
      )
      expect(status).to be_success
      expect(stdout).to include('codec_name=aac')
    end
  end

  it 'retains original audio and explains a conversion failure' do
    allow(Open3).to receive(:capture3).and_return(['', '', double(success?: false)])
    post recordings_path, params: { recording: { audio_file: audio_upload } }, headers: { 'ACCEPT' => 'application/json' }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body['error']).to include('original audio was saved')
    expect(Recording.last.audio_file).to be_attached
  end

  it 'prevents retrying another reader’s conversion' do
    owner = User.create!(name: 'Other reader', email: 'other-upload@example.test', password: 'password')
    recording = Recording.create!(recorder: owner, recordable: owner)
    post retry_conversion_recording_path(recording)
    expect(response).to redirect_to(root_url)
  end

  it 'binds the video picker to the Active Storage attachment' do
    get new_video_path
    expect(response.body).to include('name="video[video_file]"')
  end
end
