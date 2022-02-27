# frozen_string_literal: true

class Scheduler::MediaCleanupScheduler
  include Sidekiq::Worker

  sidekiq_options retry: 0

  def perform
    unattached_media.find_each(&:destroy)

    return unless Setting.media_remove_enabled

    old_media(Setting.media_remove_days).find_each do |attachment|
      next if attachment.file.blank?

      attachment.file.destroy
      attachment.thumbnail.destroy
      attachment.save
    end
  end

  private

  def unattached_media
    MediaAttachment.reorder(nil).unattached.where('created_at < ?', 1.day.ago)
  end

  def old_media(n)
    MediaAttachment.cached.remote.where('created_at < ?', n.days.ago)
  end
end
