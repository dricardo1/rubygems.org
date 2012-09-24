if Rails.env.test? || Rails.env.cucumber?
  $redis = Redis.new(:db => 1)
elsif Rails.env.recovery?
  require "fakeredis"
  $redis = Redis.new
elsif Rails.env.production?
  $redis = Redis.connect(:host => "db1")
else
  $redis = Redis.connect(:url => ENV['REDISTOGO_URL'])
end
