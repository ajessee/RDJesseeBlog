require 'rails_helper'
require 'open3'
require 'tmpdir'

RSpec.describe Recording, type: :model do
  let(:user) { FactoryBot.create(:user) }

  def wav_bytes
    stdout, stderr, status = Open3.capture3(
      'ffmpeg', '-nostdin', '-hide_banner', '-loglevel', 'error',
      '-f', 'lavfi', '-i', 'sine=frequency=440:duration=0.1', '-f', 'wav', 'pipe:1'
    )
    raise stderr unless status.success?
    stdout
  end

  it 'converts a personal recording through Active Storage without interpreting its filename as a command' do
    recording = Recording.create!(recorder: user, recordable: user,
                                  audio_file: { io: StringIO.new(wav_bytes),
                                                filename: 'family memory; $(touch injected).wav',
                                                content_type: 'audio/wav' })
    expect(recording.audio_file.blob.content_type).to eq('audio/mp4')
    recording.audio_file.blob.open do |file|
      stdout, _stderr, status = Open3.capture3('ffprobe', '-v', 'error', '-show_entries',
                                             'stream=codec_name', '-of', 'default=noprint_wrappers=1', file.path)
      expect(status).to be_success
      expect(stdout).to include('codec_name=aac')
    end
  end

  it 'retains the original attachment when conversion fails and cleans temporary output' do
    recording = Recording.create!(recorder: user, recordable: user)
    recording.audio_file.attach(io: StringIO.new('not audio'), filename: 'invalid.wav', content_type: 'audio/wav')
    original_id = recording.audio_file.blob.id
    directories_before = Dir.glob(File.join(Dir.tmpdir, 'rdjessee-audio-*'))
    expect { recording.process_audio! }.to raise_error(Recording::AudioConversionError)
    expect(recording.reload.audio_file.blob.id).to eq(original_id)
    expect(Dir.glob(File.join(Dir.tmpdir, 'rdjessee-audio-*'))).to match_array(directories_before)
  end
end
