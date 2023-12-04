# frozen_string_literal: true

class ProcessHashtagsService < BaseService
  DEFAULT_HASHTAG = 'nitiasa'
  IGNORE_DEFAULT_HASHTAG = 'notag'

  def call(status, raw_tags = [])
    @status        = status
    @account       = status.account
    @raw_tags      = status.local? ? local_tags : raw_tags
    @previous_tags = status.tags.to_a
    @current_tags  = []

    assign_tags!
    update_featured_tags!
  end

  private

  def local_tags
    tags = Extractor.extract_hashtags(@status.text)

    if tags.exclude?(DEFAULT_HASHTAG) && tags.exclude?(IGNORE_DEFAULT_HASHTAG) && @status.public_visibility? && !@status.reply?
      tags << DEFAULT_HASHTAG
      @status.update(text: "#{@status.text} ##{DEFAULT_HASHTAG}")
    end

    tags
  end

  def assign_tags!
    @status.tags = @current_tags = Tag.find_or_create_by_names(@raw_tags)
  end

  def update_featured_tags!
    return unless @status.distributable?

    added_tags = @current_tags - @previous_tags

    unless added_tags.empty?
      @account.featured_tags.where(tag_id: added_tags.map(&:id)).find_each do |featured_tag|
        featured_tag.increment(@status.created_at)
      end
    end

    removed_tags = @previous_tags - @current_tags

    unless removed_tags.empty?
      @account.featured_tags.where(tag_id: removed_tags.map(&:id)).find_each do |featured_tag|
        featured_tag.decrement(@status.id)
      end
    end
  end
end
