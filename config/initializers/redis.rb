if Rails.env.production?
  uri_s = ENV["REDISTOGO_URL"]

  if not uri_s
    container_host = ENV['REDIS_PORT_6379_TCP_ADDR'] || 'redis'
    container_port = ENV['REDIS_PORT_6379_TCP_PORT'] || 6379

    uri_s = "redis://#{container_host}:#{container_port}"
  end

  uri_o = URI.parse(uri_s)
  REDIS = Redis.new(:url => uri_o)
end
