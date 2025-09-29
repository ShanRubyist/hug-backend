require_relative '../../lib/bot'

class AigcPollingJOb < ApplicationJob
  queue_as :high

  # 最大轮询次数，避免无限循环
  MAX_ATTEMPTS = 30
  # 轮询间隔，单位：秒（可根据API预期速度调整）
  POLL_INTERVAL = 5

  def perform(ai_call_id, task_id, current_attempt = 1)
    ai_call = AiCall.find_by_id(ai_call_id)

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
    when 'failed' || 'canceled'
      # 任务失败：记录错误
      handle_failure(result[:data])
    when 'processing'
      # 任务仍在处理中
      if current_attempt < MAX_ATTEMPTS
        # 安排下一次检查
        AigcPollingJOb.perform_in(POLL_INTERVAL.seconds, ai_call_id, task_id, current_attempt + 1)
      else
        # 超过最大尝试次数，视为超时失败
        handle_failure("Polling timed out after #{MAX_ATTEMPTS} attempts.")
      end
    end
  end

  private

  def handle_failure(error_message)
    # 实现你的失败逻辑，例如记录错误、发送告警等
    Rails.logger.error "AigcPollingJOb failed: #{error_message}"
  end

  def ai_bot
    klass = ENV.fetch('AI_BOT').constantize
    klass.new
  end
end