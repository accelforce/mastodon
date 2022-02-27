# frozen_string_literal: true

class Form::MediaRemove
  include ActiveModel::Model

  BOOLEAN_KEYS = %i(
    enabled
  ).freeze

  INT_KEYS = %i(
    days
  ).freeze

  KEYS = (BOOLEAN_KEYS + INT_KEYS).freeze

  attr_accessor(*KEYS)

  validates :days, numericality: { greater_than: 1 }

  def initialize(attributes = nil)
    super
    initialize_attributes
  end

  def save
    return false unless valid?

    KEYS.each do |key|
      value = instance_variable_get("@#{key}")

      setting_key = "media_remove_#{key}"
      setting = Setting.where(var: setting_key).first_or_initialize(var: setting_key)
      setting.update(value: typecast_value(key, value))
    end
  end

  private

  def initialize_attributes
    KEYS.each do |key|
      instance_variable_set("@#{key}", Setting.public_send("media_remove_#{key}")) if instance_variable_get("@#{key}").nil?
    end
  end

  def typecast_value(key, value)
    if BOOLEAN_KEYS.include?(key)
      value == '1'
    elsif INT_KEYS.include?(key) && value.is_a?(String)
      value.to_i(10)
    else
      value
    end
  end
end
