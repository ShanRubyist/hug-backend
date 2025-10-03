require_relative '../../lib/bot'

class AigcGenerateJob < ApplicationJob
  queue_as :default

  def perform(ai_call_id, args)
    prompt = args.fetch(:prompt)
    is_polling = args.fetch(:is_polling, true)

    ai_call = AiCall.find_by_id(ai_call_id)

    task_id = ai_bot.generate_image(prompt, **args) do |h|
      ai_call.api_logs.create(input:args, data: h)
    end

    ai_call.update(task_id: task_id)

    AigcPollingJob.perform_later(ai_call_id) if is_polling
  end

  private

  def ai_bot
    klass = ENV.fetch('AI_BOT').constantize
    klass.new
  end
end