class UsageController < ApplicationController
  before_action :authenticate_user!
  before_action :check_if_maintenance_mode
  around_action :check_credits

  include CreditsCounter
  include DistributedLock

  def credits_enough?(required_credits)
    (left_credits(current_user) >= required_credits) || subscription_valid?
  end

  private

  # def has_payment?
  #   ENV.fetch('HAS_PAYMENT') == 'true' ? true : false
  # end
  #
  # def account_confirmed?
  #   current_user.confirmed?
  # end

  def subscription_valid?
    current_user.subscriptions.last&.active?
  end

  def check_credits
    locked_credits_key = "users_locked_credits:#{current_user.id}"
    @ai_call = nil

    with_redis_lock(current_user.id) do
      if credits_enough?(current_cost_credits)
        conversation = current_user.conversations.create
        @ai_call = conversation.ai_calls.create(
          prompt: params[:prompt] || '',
          status: 'submit',
          input: params[:input] || {},
          "cost_credits": current_cost_credits)

        reserved = reserve_locked_credits(locked_credits_key, @ai_call.id, current_cost_credits)
        raise "lock credit fail" unless reserved.is_a?(Integer)
      else
        render json: {
          message: 'You do not have enough credits'
        }.to_json, status: 403
        return
      end
    end

    yield

  end

  # TODO: 需要编辑
  def current_cost_credits
    case params[:model]
    when nil, 'black-forest-labs/flux-schnell'
      1
    when 'black-forest-labs/flux-dev'
      10
    when 'black-forest-labs/flux-pro'
      20
    else
      1 # 或者抛出异常
    end
  end
end