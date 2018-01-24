# helper to build up curl command strings
def curl_ssl_cmd(host, timeout=30)
  fqdn   = fact_on(host, 'fqdn')
  "curl  --connect-timeout #{timeout}" +
       ' --cacert /etc/pki/simp-testing/pki/cacerts/cacerts.pem' +
       " --cert /etc/pki/simp-testing/pki/public/#{fqdn}.pub" +
       " --key /etc/pki/simp-testing/pki/private/#{fqdn}.pem"
end
