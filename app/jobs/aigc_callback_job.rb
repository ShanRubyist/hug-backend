require_relative '../../lib/bot'

class AigcCallbackJob < ApplicationJob
  queue_as :high

  def perform(record)
    # TODO:     ai_call.update_ai_call_status(result)
    ai_bot.webhook_callback(record)
  end

  private

  def ai_bot
    klass = ENV.fetch('AI_BOT').constantize
    klass.new
  end
end