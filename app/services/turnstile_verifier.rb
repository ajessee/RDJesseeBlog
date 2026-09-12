require 'json'
require 'net/http'

class TurnstileVerifier
  ENDPOINT = URI('https://challenges.cloudflare.com/turnstile/v0/siteverify')

  class HttpClient
    def self.call(uri, form)
      request = Net::HTTP::Post.new(uri)
      request.set_form_data(form)
      Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: true,
        open_timeout: 3,
        read_timeout: 5
      ) { |http| http.request(request) }
    end
  end

  def initialize(
    secret_key: ENV['TURNSTILE_SECRET_KEY'],
    expected_hostname: ENV['TURNSTILE_HOSTNAME'],
    required: Rails.env.production?,
    http_client: HttpClient
  )
    @secret_key = secret_key
    @expected_hostname = expected_hostname
    @required = required
    @http_client = http_client
  end

  def verify(token:, remote_ip:)
    return !@required if @secret_key.blank?
    return false if token.blank?

    response = @http_client.call(
      ENDPOINT,
      secret: @secret_key,
      response: token,
      remoteip: remote_ip
    )
    return false unless response.code.to_i.between?(200, 299)

    result = JSON.parse(response.body)
    result['success'] == true && hostname_valid?(result['hostname'])
  rescue JSON::ParserError, IOError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => error
    Rails.logger.warn("Turnstile verification failed: #{error.class}")
    false
  end

  private

  def hostname_valid?(hostname)
    @expected_hostname.blank? || ActiveSupport::SecurityUtils.secure_compare(hostname.to_s, @expected_hostname)
  end
end
