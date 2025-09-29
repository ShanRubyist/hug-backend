class SaveToOssJob < ApplicationJob
  queue_as :high

  def perform(ai_call_id, type = :generated_media, args)
    media = args.fetch(:io)
    media = media.first if media.class == Array

    io = case media
         when String
           require 'open-uri'
           URI.open(media)
         when Tempfile
           media
         end


    ai_call = AiCall.find_by_id(ai_call_id)
    ai_call
      .send(type.to_sym)
      .attach(io: io, filename: args.fetch(:filename), content_type: args.fetch(:content_type))
  end
end