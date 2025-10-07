module DistributedLock
  extend ActiveSupport::Concern

  included do |base|
  end

  module ClassMethods
  end

  def with_redis_lock(key, timeout = 60, max_attempts = 5, retry_delay = 1)
    lock_key = "user_lock:#{key}"
    lock_value = SecureRandom.uuid

    attempt = 0
    while attempt < max_attempts
      begin
        if redis_client.set(lock_key, lock_value, nx: true, ex: timeout)
          begin
            return yield
          ensure
            release_lock(lock_key, lock_value)
          end
        end
      rescue Redis::BaseError => e
        Rails.logger.error("Redis error during lock acquisition: #{e.message}")
        raise "Failed to acquire lock due to Redis error: #{e.message}"
      end

      attempt += 1
      sleep retry_delay if attempt < max_attempts
    end

    raise "Failed to acquire lock for #{key} after #{max_attempts} attempts"
  end

  private

  def redis_client
    if block_given?
      RedisClient.with { |conn| yield conn }
    else
      RedisClient.instance
    end
  end

  def release_lock(lock_key, lock_value)
    lua_script = <<-LUA
    if redis.call("GET", KEYS[1]) == ARGV[1] then
      return redis.call("DEL", KEYS[1])
    else
      return 0
    end
    LUA

    result = redis_client.eval(lua_script, keys: [lock_key], argv: [lock_value])
    Rails.logger.warn("Lock already released: #{lock_key}") if result == 0
  rescue Redis::BaseError => e
    Rails.logger.error("Failed to release lock: #{e.message}")
  end
end