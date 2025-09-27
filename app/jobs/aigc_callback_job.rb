require_relative '../../lib/bot'

class AigcCallbackJob < ApplicationJob
  queue_as :high

  def perform(record)
    ai_bot.webhook_callback(record)
  end

  private

  def ai_bot
    klass = ENV.fetch('AI_BOT').constantize
    klass.new
  end
end