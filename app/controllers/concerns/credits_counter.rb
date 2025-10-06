module CreditsCounter
  extend ActiveSupport::Concern

  included do |base|
  end

  def total_credits(user)
    user.charges
        .where("amount_refunded is null or amount_refunded = 0")
        .inject(0) { |sum, item| sum + item.metadata.fetch("credits").to_i }
  end

  def total_used_credits(user)
    user.conversations.inject(0) { |sum, item| sum + used_credits(item) }
  end

  def left_credits(user)
    # Calculate available credits based on your formula:
    # 可用积分 = 用户全部积分（数据库实时获取）- 成功生成扣除的积分（数据库实时获取）- 预扣积分（redis获取）

    total_credits_db = total_credits(user)
    total_used_credits_db = total_used_credits(user)

    # Get locked credits from Redis
    locked_credits_key = "users_locked_credits:#{user.id}"
    locked_credits = current_locked_credits(locked_credits_key)

    credits = total_credits_db - total_used_credits_db - locked_credits + (ENV.fetch('FREEMIUM_CREDITS') { 0 }).to_i

    credits = 0 if credits < 0
    return credits
  end

  def used_credits(conversation)
    conversation.ai_calls.succeeded_ai_calls.sum(:cost_credits)
  end

  def current_locked_credits(locked_credits_key)
    # Get total locked credits for the user
    # This includes both general locked credits and generation-specific locked credits
    total_locked = redis_client.get(locked_credits_key).to_i

    # Get all generation-specific locked credits for this user
    generation_keys = redis_client.keys("#{locked_credits_key}:generation:*")
    generation_locked = generation_keys.sum { |key| redis_client.get(key).to_i }

    total_locked + generation_locked
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
    Redis.new(url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" })
  end

  module ClassMethods
  end
end
