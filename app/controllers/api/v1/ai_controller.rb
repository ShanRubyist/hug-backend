require 'bot'

class Api::V1::AiController < UsageController
  skip_around_action :check_credits, only: [:ai_call_info, :gen_callback, :gen_task_status, :generate_presigned_url]
  skip_before_action :check_if_maintenance_mode, only: [:ai_call_info, :gen_callback, :gen_task_status]

  def generate_presigned_url
    # 安全验证文件类型
    # content_type = Mime::Types.type_for(params[:filename]).first.to_s
    # allowed_types = ['image/jpeg', 'image/png', 'image/gif']
    #
    # unless allowed_types.include?(content_type)
    #   return render json: { error: '不支持的文件类型' }, status: 400
    # end

    object_key = "uploads/#{SecureRandom.uuid}-#{params[:filename]}"

    presigned_url = R2_PRESIGNER.presigned_url(
      :put_object,
      bucket: ENV.fetch('R2_BUCKET'),
      key: object_key,
      expires_in: 300 # 5 min
    )

    render json: {
      presigned_url: presigned_url,
      object_key: object_key,
      public_url: "https://#{ENV['R2_PUBLIC_DOMAIN']}/#{object_key}"
    }
  end

  def gen_image
    type = params['type']
    raise 'type can not be empty' unless type.present?

    prompt = params['prompt'] || 'GHBLI anime style photo'
    raise 'prompt can not be empty' unless prompt.present?

    image = params['image']
    raise 'image can not be empty' unless image.present?

    model_name = 'aaronaftab/mirage-ghibli'

    conversation = current_user.conversations.create
    ai_call = conversation.ai_calls.create(
      task_id: SecureRandom.uuid,
      prompt: prompt,
      status: 'submit',
      input: params,
      "cost_credits": current_cost_credits)

    AigcJob.perform_later(ai_call.id,
                          { model_name: model_name, image: image,
                            type: type,
                            prompt: prompt
                          })

    render json: {
      id: ai_call.id
    }
  end

  def gen_video
    conversation = current_user.conversations.create
    prompt = params['prompt']

    # generate video task
    task_id = ai_bot.generate_video(prompt)

    task_id = task_id.id if ai_bot.class == Bot::Replicate

    ai_call = conversation.ai_calls.create(
      task_id: task_id,
      prompt: params[:prompt],
      status: 'submit',
      input: params,
      "cost_credits": current_cost_credits)

    render json: {
      task_id: task_id
    }
  end

  def gen_callback
    begin
      ai_bot = ENV.fetch('AI_BOT').constantize
      record = AigcWebhook.create!(data: request.body.read, headers: request.headers.read)

      if ai_bot === Bot::MiniMax
        rst = ai_bot.webhook_callback(params, record)
        if rst && (rst.class == String)
          # For HaiLuo Video
          render json: rst
        end
      else
        AigcCallbackJob.perform_later(record)
        head :ok

      end
      # rescue
      #   head :bad_request
    end
  end

  def gen_task_status
    id = params['id']
    ai_call = AiCall.find_by_id(id)

    if ai_call
      payload = ai_call.data

      render json: {
        status: ((payload['status'] || payload['data']['status']) rescue nil),
        media_url: ((payload['video'] || payload['data']['output']) rescue nil)
      }
    else
      fail "[Controller] ID #{id} not exist"
    end

  end

  def ai_call_info
    params[:page] ||= 1
    params[:per] ||= 20

    ai_calls = AiCall.joins(conversation: :user).where(users: { id: current_user.id })
                     .order("created_at desc")
                     .page(params[:page].to_i)
                     .per(params[:per].to_i)

    result = ai_calls.map do |item|
      {
        # input_media: (
        #   item.input_media.map do |media|
        #     url_for(media)
        #   end
        # ),
        generated_media: (
          item.generated_media.map do |media|
            url_for(media)
          end
        ),
        prompt: item.prompt,
        status: item.status,
        input: item.input,
        data: item.data,
        created_at: item.created_at,
        cost_credits: item.cost_credits,
        system_prompt: item.system_prompt,
        business_type: item.business_type
      }
    end

    render json: {
      total: ai_calls.total_count,
      histories: result
    }
  end

  private

end