class Download
  COUNT_KEY     = "downloads"
  ALL_KEY       = "downloads:all"

  def self.incr(name, full_name)
    today = Time.zone.today.to_s
    $redis.incr(COUNT_KEY)
    $redis.incr(rubygem_key(name))
    $redis.incr(version_key(full_name))
    $redis.zincrby(today_key, 1, full_name)
    $redis.zincrby(ALL_KEY, 1, full_name)
    $redis.hincrby(version_history_key(full_name), today, 1)
    $redis.hincrby(rubygem_history_key(name), today, 1)
  end

  def self.count
    $redis.get(COUNT_KEY).to_i
  end

  def self.today(*versions)
    versions.flatten.inject(0) do |sum, version|
      sum + $redis.zscore(today_key, version.full_name).to_i
    end
  end

  def self.for(what)
    $redis.get(key(what)).to_i
  end

  def self.for_rubygem(name)
    $redis.get(rubygem_key(name)).to_i
  end

  def self.for_version(full_name)
    $redis.get(version_key(full_name)).to_i
  end

  def self.most_downloaded_today(n=5)
    items = $redis.zrevrange(today_key, 0, (n-1), :with_scores => true)
    items.collect do |full_name, downloads|
      version = Version.find_by_full_name(full_name)
      [version, downloads.to_i]
    end
  end

  def self.most_downloaded_all_time(n=5)
    items = $redis.zrevrange(ALL_KEY, 0, (n-1), :with_scores => true)
    items.collect do |full_name, downloads|
      version = Version.find_by_full_name(full_name)
      [version, downloads.to_i]
    end
  end

  def self.counts_by_day_for_versions(versions, days)
    dates = (days.days.ago.to_date...Time.zone.today).map(&:to_s)

    downloads = {}
    versions.each do |version|
      key = history_key(version)

      $redis.hmget(key, *dates).zip(dates).each do |count, date|
        if count
          count = count.to_i
        else
          vh = VersionHistory.where(:version_id => version.id,
                                    :day => date).first

          count = vh ? vh.count : 0
        end

        downloads["#{version.id}-#{date}"] = count
      end
      downloads["#{version.id}-#{Time.zone.today}"] = self.today(version)
    end

    downloads
  end

  def self.counts_by_day_for_version_in_date_range(version, start, stop)
    downloads = ActiveSupport::OrderedHash.new

    dates = (start..stop).map(&:to_s)

    $redis.hmget(history_key(version), *dates).zip(dates).each do |count, date|
      if count
        count = count.to_i
      else
        vh = VersionHistory.where(:version_id => version.id,
                                  :day => date).first

        if vh
          count = vh.count
        else
          count = 0
        end
      end

      downloads[date] = count
    end

    if stop == Time.zone.today
      stop -= 1.day
      downloads["#{Time.zone.today}"] = self.today(version)
    end

    downloads
  end

  def self.copy_to_sql(version, date)
    count = $redis.hget(history_key(version), date)

    if vh = VersionHistory.for(version, date)
      vh.count = count
      vh.save
    else
      VersionHistory.make(version, date, count)
    end
  end

  def self.migrate_to_sql(version)
    key = history_key version

    dates = $redis.hkeys(key)

    back = 1.days.ago.to_date

    dates.delete_if { |e| Date.parse(e) >= back }

    dates.each do |d|
      copy_to_sql version, d
      $redis.hdel key, d
    end

    dates
  end

  def self.migrate_all_to_sql
    count = 0
    Version.all.each do |ver|
      dates = migrate_to_sql ver
      count += 1 unless dates.empty?
    end

    count
  end

  def self.counts_by_day_for_version(version)
    counts_by_day_for_version_in_date_range(version, Time.zone.today - 89.days, Time.zone.today)
  end

  def self.key(what)
    case what
    when Version
      version_key(what.full_name)
    when Rubygem
      rubygem_key(what.name)
    else
      raise TypeError, "Unknown type for key - #{what.class}"
    end
  end

  def self.history_key(what)
    case what
    when Version
      version_history_key(what.full_name)
    when Rubygem
      rubygem_history_key(what.name)
    else
      raise TypeError, "Unknown type for history_key - #{what.class}"
    end
  end

  def self.cardinality
    $redis.zcard(today_key)
  end

  def self.rank(version)
    if rank = $redis.zrevrank(today_key, version.full_name)
      rank + 1
    else
      0
    end
  end

  def self.highest_rank(versions)
    ranks = versions.map { |version| Download.rank(version) }.reject(&:zero?)
    if ranks.empty?
      0
    else
      ranks.min
    end
  end

  def self.cleanup_today_keys
    $redis.del(*today_keys)
  end

  def self.today_keys
    today_keys = $redis.keys("downloads:today:*")
    today_keys.delete(today_key)
    today_keys
  end

  def self.today_key(date_string=Time.zone.today)
    "downloads:today:#{date_string}"
  end

  def self.version_history_key(full_name)
    "downloads:version_history:#{full_name}"
  end

  def self.rubygem_history_key(name)
    "downloads:rubygem_history:#{name}"
  end

  def self.version_key(full_name)
    "downloads:version:#{full_name}"
  end

  def self.rubygem_key(name)
    "downloads:rubygem:#{name}"
  end
end
