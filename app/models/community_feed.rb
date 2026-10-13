# frozen_string_literal: true

class CommunityFeed < PublicFeed
  def initialize(account, options = {})
    super(account, options.merge(local: true, remote: true, with_replies: true))
  end

  def get(...)
    return [] unless user_has_access_to_feed?(local_feed_setting)

    super
  end

  private

  def public_scope
    super.tagged_with(Tag.matching_name(DefaultHashtag::NAME).select(:id))
  end
end
