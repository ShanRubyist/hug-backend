class AiCall < ApplicationRecord
  belongs_to :conversation
  has_many :api_logs

  has_many_attached :input_media
  has_many_attached :generated_media

  scope :succeeded_ai_calls, -> { where("ai_calls.status = ?", 'success') }

  # 使用 after_update 回调来监听状态变化
  after_update :status_change_callback#, if: :status_changed?
  include CreditsCounter

  def update_ai_call_status(h)
    self.update(status: h[:status], data: h)
  end

  private

  def status_change_callback
    locked_credits_key = "users_locked_credits:#{self.conversation.user.id}"

    case status
    when 'success'
      release_locked_credits(locked_credits_key, id)
    when 'failed'
      release_locked_credits(locked_credits_key, id)
    end
  end
end
