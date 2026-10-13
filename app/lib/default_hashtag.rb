# frozen_string_literal: true

module DefaultHashtag
  NAME = 'nitiasa'
  OPT_OUT = 'notag'

  def self.tags(status)
    tags = Extractor.extract_hashtags(status.text)
    tags << NAME if required?(status, tags)
    tags
  end

  def self.text(status)
    return status.text unless required?(status)

    "#{status.text} ##{NAME}".strip
  end

  def self.required?(status, tags = nil)
    return false unless status.local? && status.visibility == 'public' && !status.reply? && !status.reblog?

    (tags || Extractor.extract_hashtags(status.text)).none? { |tag| [NAME, OPT_OUT].include?(Tag.normalize_value_for(:name, tag)) }
  end
  private_class_method :required?
end
