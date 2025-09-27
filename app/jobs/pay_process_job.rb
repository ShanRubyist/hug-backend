require_relative '../../lib/pay/creem/charge'

class PayProcessJob < ApplicationJob
  queue_as :critical

  def perform(event)
    Pay::Creem::Charge.sync(event)
  end
end