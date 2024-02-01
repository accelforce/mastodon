# frozen_string_literal: true

class LinkCrawlWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'pull', retry: 0

  def perform(status_id)
    FetchLinkCardService.new.call(Status.find(status_id))
  rescue OpenSSL::SSL::SSLError, ActiveRecord::RecordNotFound, ActiveRecord::RecordNotUnique
    true
  end
end
