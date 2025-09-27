require_relative '../../lib/bot'

class AigcJob < ApplicationJob
  queue_as :high

  def perform(ai_call_id, args)
    image = args.fetch(:image)
    type = args.fetch(:type)
    prompt = args.fetch(:prompt)
    model_name = args.fetch(:model_name)
    is_polling = args.fetch(:is_polling, true)
    input = args.fetch(:input, {})

    ai_call = AiCall.find_by_id(ai_call_id)

    task_id = ai_bot.generate_image(prompt, image: image, model_name: model_name) do |response|
      ai_call.api_logs.create(input:input, data: response, task_id: task_id)
    end

    ai_bot.polling(ai_call, task_id, image) if is_polling
  end

  private

  def ai_bot
    klass = ENV.fetch('AI_BOT').constantize
    klass.new
  end
end