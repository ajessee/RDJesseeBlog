require 'rails_helper'

RSpec.describe TurnstileVerifier do
  Response = Struct.new(:code, :body)

  it 'accepts a successful response for the configured hostname' do
    http_client = ->(_uri, _form) { Response.new('200', { success: true, hostname: 'www.example.test' }.to_json) }
    verifier = described_class.new(
      secret_key: 'test-secret',
      expected_hostname: 'www.example.test',
      required: true,
      http_client: http_client
    )

    expect(verifier.verify(token: 'test-token', remote_ip: '127.0.0.1')).to be(true)
  end

  it 'rejects failed, malformed, or wrong-host responses' do
    responses = [
      Response.new('200', { success: false }.to_json),
      Response.new('200', 'not json'),
      Response.new('200', { success: true, hostname: 'attacker.example' }.to_json),
      Response.new('503', { success: true, hostname: 'www.example.test' }.to_json)
    ]

    responses.each do |response|
      verifier = described_class.new(
        secret_key: 'test-secret',
        expected_hostname: 'www.example.test',
        required: true,
        http_client: ->(_uri, _form) { response }
      )
      expect(verifier.verify(token: 'test-token', remote_ip: '127.0.0.1')).to be(false)
    end
  end

  it 'fails closed without a production secret while allowing unconfigured local development' do
    expect(described_class.new(secret_key: nil, required: true).verify(token: nil, remote_ip: nil)).to be(false)
    expect(described_class.new(secret_key: nil, required: false).verify(token: nil, remote_ip: nil)).to be(true)
  end

  it 'fails closed when the verification service cannot be reached' do
    http_client = ->(_uri, _form) { raise SocketError, 'synthetic DNS failure' }
    verifier = described_class.new(secret_key: 'test-secret', required: true, http_client: http_client)

    expect(verifier.verify(token: 'test-token', remote_ip: '127.0.0.1')).to be(false)
  end
end
