# frozen_string_literal: true

class AvatarEmoji < ActiveModelSerializers::Model
  attributes :account, :shortcode

  SCAN_RE = /:(@[a-z0-9_]+(?:@[a-z0-9.-]+[a-z0-9]+)?):/i

  def self.from_text(text, domain = nil)
    return [] if text.blank?

    text.scan(SCAN_RE).flatten.uniq.filter_map do |shortcode|
      username, host = shortcode.delete_prefix('@').split('@')
      host ||= domain
      host = nil if TagManager.instance.local_domain?(host)
      account = Account.find_remote(username, host)

      new(account: account, shortcode: shortcode) if account
    end
  end

  def image
    @image ||= Image.new(account.avatar)
  end

  def visible_in_picker
    false
  end

  Image = Struct.new(:attachment) do
    delegate :content_type, to: :attachment

    def url(style = :original)
      attachment.url(style == :static && content_type != 'image/gif' ? :original : style)
    end
  end
end
