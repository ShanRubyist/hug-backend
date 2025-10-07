module CreditsCounter
  extend ActiveSupport::Concern

  included do |base|
  end

  def total_credits(user)
    user.charges
        .where("amount_refunded is null or amount_refunded = 0")
        .inject(0) { |sum, item| sum + item.metadata.fetch("credits", 0).to_i }

  end

  def total_used_credits(user)
    user.conversations
        .joins(:ai_calls)
        .merge(AiCall.succeeded_ai_calls)
        .sum('ai_calls.cost_credits')
  end

  def parse_freemium_credits
    freemium_credits = ENV.fetch('FREEMIUM_CREDITS') { '0' }
    Integer(freemium_credits) rescue 0
  end

  def left_credits(user)
    # Calculate available credits based on your formula:
    # 可用积分 = 用户全部积分（数据库实时获取）- 成功生成扣除的积分（数据库实时获取）- 预扣积分（redis获取）

    total_credits_db = total_credits(user)
    total_used_credits_db = total_used_credits(user)

    # Get locked credits from Redis
    locked_credits_key = "users_locked_credits:#{user.id}"
    locked_credits = current_locked_credits(locked_credits_key)

    credits = total_credits_db - total_used_credits_db - locked_credits + parse_freemium_credits

    credits = 0 if credits < 0
    return credits
  end

  def current_locked_credits(locked_credits_key)
    pattern = "#{locked_credits_key}:generation:*"
    cursor = "0"
    total = 0

    # 使用SCAN代替KEYS
    loop do
      cursor, keys = redis_client.scan(cursor, match: pattern, count: 100)
      total += keys.sum { |key| redis_client.get(key).to_i }
      break if cursor == "0"
    end

    total
  rescue Redis::BaseError => e
    Rails.logger.error("Redis error in current_locked_credits: #{e.message}")
    0 # 降级处理
  end

  # 预扣积分（图片生成开始时）
  def reserve_locked_credits(locked_credits_key, generation_id, amount)
    generation_key = "#{locked_credits_key}:generation:#{generation_id}"

    # Set expiration time for the reservation (e.g., 30 minutes)
    expiration_time = 30 * 60

    # Reserve credits in Redis with expiration
    reserved_amount = redis_client.incrby(generation_key, amount)
    redis_client.expire(generation_key, expiration_time)

    reserved_amount
  end

  # 确认扣除积分（生成成功时）
  def release_locked_credits(locked_credits_key, generation_id)
    generation_key = "#{locked_credits_key}:generation:#{generation_id}"

    # Release the locked credits from this generation
    redis_client.del(generation_key)
  end


  def redis_client
    if block_given?
      RedisClient.with { |conn| yield conn }
    else
      RedisClient.instance
    end
  end

  module ClassMethods
  end
end
