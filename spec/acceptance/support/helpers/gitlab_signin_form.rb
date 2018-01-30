require 'nokogiri'

class GitlabSigninForm
  attr_reader :form, :header_csrf_token, :action

  def initialize(html)
    doc = Nokogiri::HTML(html)
    @form = parse_form(doc)
    @header_csrf_token = doc.at("meta[name='csrf-token']")['content']
    @action = @form['action']
  end

  # Returns a hash of all input elements in a completed signin form
  def signin_post_data(username, password)
      @form.css('input#username').first['value'] = username
      @form.css('input#password').first['value'] = password
      input_data_hash = form.css('input').map do |x|
        {
          :name  => x['name'],
          :type  => x['type'],
          :value => (x['value'] || nil)
        }
      end
      input_data_hash.select{|x| x[:name] == 'authenticity_token' }.first[:value] = @header_csrf_token
      input_data_hash
  end

  private

  def parse_form(doc)
    form = doc.at_css('form#new_ldap_user')
    msg = ''
    if form.nil?
      msg = "Nokogiri didn't find the expected `form#new_ldap_user`"
    elsif form.at_css('input#username').nil?
      msg = "Nokogiri didn't find the expected `input#username`"
    end

    unless msg.empty?
      warn "WARNING: #{msg}", '-'*80, ''
      if ENV['PRY'] == 'yes'
        warn "ENV['PRY'] is set to 'yes'; switching to pry console"
        binding.pry
      end
      fail "ERROR: Not a recognizable signin form"
    end
    form
  end
end
