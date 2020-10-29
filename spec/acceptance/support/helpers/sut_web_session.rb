# Provides a persistent web browsing session using curl from a SUT client
#
class SutWebSession
  attr_reader   :client, :cookie_file, :header_file, :gitlab_signin_url
  attr_accessor :previous_url

  def initialize(client)
    @unique_str   = "#{Array.new(8).map{|x|(65 + rand(25)).chr}.join}_#{$$}"
    @cookie_file  = "/tmp/cookies_#{@unique_str}.txt"
    @header_file  = "/tmp/headers_#{@unique_str}.txt"
    @client       = client
    @curl_cmd     = curl_ssl_cmd(@client)
    @previous_url = nil
    @retries      = ENV['BEAKER_gitlab_retries'] || 6
  end

  def curl_get(url)
    curl_args      = "-c #{@cookie_file} -D #{@header_file} -L '#{url}' --retry #{@retries}"
    result         = curl_on_client(curl_args)
    @previous_url  = url if result
    result
  end

  def curl_post(url, post_data_hash)
    post_data = URI.encode_www_form(Hash[post_data_hash.map{ |x| [x[:name], x[:value]] }])
    curl_args     = "-b #{@cookie_file} -c #{@cookie_file} -D #{@header_file}" +
                    " -L '#{url}' -d '#{post_data}'"
    result        = curl_on_client(curl_args)
    @previous_url = url if result
    result
  end

  def curl_on_client(curl_args)
    # I don't know if referer is necessary to avoid XSS (the authenticity
    # token should be enough for logins),
    curl_args            += " --referer '#{@previous_url}'" if @previous_url
    result                = on(@client, "#{@curl_cmd} #{curl_args}")
    failed_response_codes = headers.scan(%r[HTTP/1\.\d (\d\d\d) .*$])
                                   .flatten
                                   .select{|x| x !~ /^[23]\d\d/ }
    unless failed_response_codes.empty?
      warn '', '-'*80, "REMINDER: web server returned response codes " +
           "(#{failed_response_codes.join(',')}) during login", '-'*80, ''
      if ENV['PRY'] == 'yes'
        warn "ENV['PRY'] is set to 'yes'; switching to pry console"
        binding.pry
      end
    end
    result.stdout
  end

  def cookies
    on(@client, "cat #{@cookie_file}").stdout
  end

  def headers
    on(@client, "cat #{@header_file}").stdout
  end
end

