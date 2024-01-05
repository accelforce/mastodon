# frozen_string_literal: true

require 'rails_helper'

describe StatusLengthValidator do
  describe '#validate' do
    it 'does not add errors onto remote statuses' do
      status = instance_double(Status, local?: false)
      allow(status).to receive(:errors)

      subject.validate(status)

      expect(status).to_not have_received(:errors)
    end

    it 'does not add errors onto local reblogs' do
      status = instance_double(Status, local?: false, reblog?: true)
      allow(status).to receive(:errors)

      subject.validate(status)

      expect(status).to_not have_received(:errors)
    end

    it 'adds an error when content warning is over 4096 characters' do
      status = instance_double(Status, spoiler_text: 'a' * 5000, text: '', errors: activemodel_errors, local?: true, reblog?: false)
      subject.validate(status)
      expect(status.errors).to have_received(:add)
    end

    it 'adds an error when text is over 4096 characters' do
      status = instance_double(Status, spoiler_text: '', text: 'a' * 5000, errors: activemodel_errors, local?: true, reblog?: false)
      subject.validate(status)
      expect(status.errors).to have_received(:add)
    end

    it 'adds an error when text and content warning are over 4096 characters total' do
      status = instance_double(Status, spoiler_text: 'a' * 2500, text: 'b' * 2500, errors: activemodel_errors, local?: true, reblog?: false)
      subject.validate(status)
      expect(status.errors).to have_received(:add)
    end

    it 'counts URLs as 23 characters flat' do
      text   = ('a' * 4072) + " http://#{'b' * 30}.com/example"
      status = instance_double(Status, spoiler_text: '', text: text, errors: activemodel_errors, local?: true, reblog?: false)

      subject.validate(status)
      expect(status.errors).to_not have_received(:add)
    end

    it 'does not count non-autolinkable URLs as 23 characters flat' do
      text   = ('a' * 4072) + "http://#{'b' * 30}.com/example"
      status = instance_double(Status, spoiler_text: '', text: text, errors: activemodel_errors, local?: true, reblog?: false)

      subject.validate(status)
      expect(status.errors).to have_received(:add)
    end

    it 'does not count overly long URLs as 23 characters flat' do
      text = "http://example.com/valid?#{'#foo?' * 1000}"
      status = instance_double(Status, spoiler_text: '', text: text, errors: activemodel_errors, local?: true, reblog?: false)
      subject.validate(status)
      expect(status.errors).to have_received(:add)
    end

    it 'counts only the front part of remote usernames' do
      text   = ('a' * 4072) + " @alice@#{'b' * 30}.com"
      status = instance_double(Status, spoiler_text: '', text: text, errors: activemodel_errors, local?: true, reblog?: false)

      subject.validate(status)
      expect(status.errors).to_not have_received(:add)
    end

    it 'does count both parts of remote usernames for overly long domains' do
      text   = "@alice@#{'b' * 5000}.com"
      status = instance_double(Status, spoiler_text: '', text: text, errors: activemodel_errors, local?: true, reblog?: false)

      subject.validate(status)
      expect(status.errors).to have_received(:add)
    end
  end

  private

  def activemodel_errors
    instance_double(ActiveModel::Errors, add: nil)
  end
end
