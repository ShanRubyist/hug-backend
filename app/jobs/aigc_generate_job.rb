require_relative '../../lib/bot'

class AigcGenerateJob < ApplicationJob
  queue_as :default

  def perform(ai_call_id, args)
    images = args.fetch(:images)
    prompt = args.fetch(:prompt)
    model_name = args.fetch(:model_name)
    is_polling = args.fetch(:is_polling, true)

    ai_call = AiCall.find_by_id(ai_call_id)

    task_id = ai_bot.generate_image(prompt, image_input: images, model_name: model_name) do |h|
      ai_call.api_logs.create(input:args, data: h)
    end

    ai_call.update(task_id: task_id)

    AigcPollingJOb.perform_later(ai_call_id, task_id) if is_polling
  end

  private

  def ai_bot
    klass = ENV.fetch('AI_BOT').constantize
    klass.new
  end
end