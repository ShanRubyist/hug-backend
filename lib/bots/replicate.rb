require 'bot'

module Bot
  class Replicate < AIModel
    def initialize
    end

    # def video_api(prompt, options = {})
    #   model_name = options.fetch(:model_name, 'kwaivgi/kling-v1.6-standard')
    #   model = ::Replicate.client.retrieve_model(model_name)
    #
    #   version = model.latest_version
    #   webhook_url = "https://" + ENV.fetch("HOST") + "/replicate/webhook"
    #
    #   prediction = version.predict(
    #     {
    #       prompt: prompt,
    #       # image: options.fetch(:image),
    #     },
    #     webhook_url
    #   )
    #
    #   prediction
    # end

    def image_api(prompt, options = {}, &block)
      model_name = options.fetch(:model_name)
      model = ::Replicate.client.retrieve_model(model_name)

      version = model.latest_version

      prediction = version.predict(
        prompt: prompt,
        **options,
      # aspect_ratio: aspect_ratio,
      # disable_safety_checker: true,
      # go_fast: true,
      # guidance_scale: 10,
      # prompt_strength: 0.77,
      # num_inference_steps: 38,
      # afety_tolerance: 5,
      )

      yield(prediction) if block_given?

      prediction.id
    end

    # def callback(webhook_record)
    #   prediction = webhook_record.data
    #   return unless prediction.succeeded? || prediction.failed? || prediction.canceled?
    #
    #   ai_call = AiCall.find_by_task_id(prediction.id)
    #
    #   if ai_call
    #     ai_call.update!(
    #       status: prediction.status,
    #       data: prediction
    #     )
    #     if prediction.succeeded?
    #       video = prediction.output
    #       # OSS
    #       require 'open-uri'
    #       SaveToOssJob.perform_later(ai_call,
    #                                :generated_media,
    #                                {
    #                                  io: video,
    #                                  filename: URI(video).path.split('/').last,
    #                                  content_type: "video/mp4"
    #                                }
    #       )
    #     end
    #     webhook_record.destroy
    #   else
    #     fail "[Replicate]task id not exist"
    #   end
    # end

    def query_image_task_api(id, &block)
      prediction = ::Replicate.client.retrieve_prediction(id)

      data = prediction.refetch

      if prediction.succeeded?
        rst =  {
          status: 'success',
          media: prediction.output,
          data: data
        }
      elsif prediction.failed? || prediction.canceled?
        fail 'generate image failed or canceled:' + data.fetch('error')
      else
        rst =  {
          status: data['status'],
          media: prediction&.output,
          data: data
        }
      end

      yield(rst) if block_given?

      return rst

    end
  end
end