require_relative '../../lib/bot'

class AigcPollingJob < ApplicationJob
  queue_as :high

  # 最大轮询次数，避免无限循环
  MAX_ATTEMPTS = 100
  # 轮询间隔，单位：秒（可根据API预期速度调整）
  POLL_INTERVAL = 10

  def perform(ai_call_id, current_attempt = 1)
    ai_call = AiCall.find_by_id(ai_call_id)
    task_id = ai_call.task_id

    result = ai_bot.query_image_task_api(task_id) do |h|
      ai_call.api_logs.create(input: { task_id: task_id }, data: h)
    end
    ai_call.update_ai_call_status(result)

    case result[:status]
    when 'success'
      # OSS
      require 'open-uri'
      SaveToOssJob.perform_later(ai_call,
                                 :generated_media,
                                 {
                                   io: result[:media],
                                   filename: SecureRandom.uuid.to_s,
                                   content_type: "image/jpeg"
                                 }
      )
    when 'failed', 'canceled'
      # 任务失败：记录错误
      handle_failure(result[:data])
    when 'processing', 'starting'
      # 任务仍在处理中
      if current_attempt < MAX_ATTEMPTS
        # 安排下一次检查
        AigcPollingJob
          .set({wait: POLL_INTERVAL.seconds})
          .perform_later(ai_call_id, current_attempt + 1)
      else
        # 超过最大尝试次数，视为超时失败
        handle_failure("Polling timed out after #{MAX_ATTEMPTS} attempts.")
      end
    end
  end

  private

  def handle_failure(error_message)

    # ErrorLog.create(
    #   origin_type: 0,
    #   error_type: error_params[:error_type],
    #   message: error_message,
    #   backtrace: error_params[:backtrace],
    #   user_email: current_user.email
    # )
  end

  def ai_bot
    klass = ENV.fetch('AI_BOT').constantize
    klass.new
  end
end