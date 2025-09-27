require_relative '../../lib/bot'

class AigcJob < ApplicationJob
  queue_as :high

  def perform(ai_bot, ai_call_id, args)
    ai_call=AiCall.find_by_id('f4f8e4dc-1cc0-4297-b4c3-efe9b407ab00')
    # polling(ai_bot, ai_call, ai_call., args.fetch(:image))
  end

  def perform2(ai_bot, ai_call_id, args)
    image = args.fetch(:image)
    type = args.fetch(:type)
    prompt = args.fetch(:prompt)
    model_name = args.fetch(:model_name)
    is_polling = args.fetch(:is_polling, true)
    input = args.fetch(:input, {})

    ai_call = AiCall.find_by_id(ai_call_id)

    # if type.to_i == 0
    #   # OSS
    #   SaveToOssJob.perform_now(ai_call,
    #                            :input_media,
    #                            {
    #                              io: image.tempfile,
    #                              filename: image.original_filename + Time.now.to_s,
    #                              content_type: image.content_type
    #                            }
    #   )
    #   image = url_for(ai_call.input_media.last)
    # end

    task_id = ai_bot.generate_image(prompt, image: image, model_name: model_name) do |response|
      ai_call.api_logs.create(input:input, data: response, task_id: task_id)
    end

    ai_bot.polling(ai_call, task_id, image) if is_polling
  end
end