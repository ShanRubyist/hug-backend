class RedisClient
  @pool = ConnectionPool.new(size: 5, timeout: 5) do
    Redis.new(url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" })
  end

  class << self
    def with(&block)
      @pool.with(&block)
    end

    def instance
      @pool.with { |conn| conn }
    end
  end
end