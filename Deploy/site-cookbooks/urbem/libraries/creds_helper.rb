module Creds
  module Helper

    def creds_h
      if node["key_file"]
        secret = Chef::EncryptedDataBagItem.load_secrets("#{node['key_file']['path']}")
        creds = Chef::EncryptedDataBagItem.load("urbem", "keys", secret)
      else
        creds = data_bag_item('keys', 'secret')
      end

      creds
    end

    def list_creds
        creds = creds_h

        list_creds = [
          "MAILER_FROM=#{creds['email']}",
          "FACEBOOK_SECRET=#{creds['facebook']['secret']}",
          "FACEBOOK_KEY=#{creds['facebook']['key']}",
          "TWITTER_KEY=#{creds['twitter']['key']}",
          "TWITTER_SECRET=#{creds['twitter']['secret']}",
          "TWITTER_OAUTH_TOKEN=#{creds['twitter']['oauth_token']}",
          "TWITTER_OAUTH_TOKEN_SECRET=#{creds['twitter']['oauth_token_secret']}",
          "SENDGRID_USERNAME=#{creds['sendgrid']['username']}",
          "SENDGRID_PASSWORD=#{creds['sendgrid']['password']}",
          "COVERALLS_TOKEN=#{creds['coverall_token']}",
          "SECRET_KEY_BASE=#{creds['rails']['secret_key_base']}",
          "RAILS_ENV=#{creds['rails']['env']}",
          "PASSENGER_APP_ENV=#{creds['rails']['env']}",
          "POSTGRES_PASSWORD=#{creds['postgres']['password']}",
          "S3_BUCKET=#{creds['aws']['s3_bucket_name']}",
          "AWS_SECRET=#{creds['aws']['aws_secret']}",
          "AWS_KEY=#{creds['aws']['aws_key']}"
        ]

        list_creds.push "APP_NAME=#{if creds['app_name'] then  creds['app_name'] else "urbem" end}"
        list_creds.push "HOST=#{if creds['host'] then  creds['host'] else "urbem:80" end}"

        list_creds
    end

    def postgres_pwd
      creds = creds_h
      creds['postgres']['password']
    end
  end
end
