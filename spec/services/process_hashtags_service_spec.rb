# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessHashtagsService do
  describe '#call' do
    let(:status) { Fabricate(:status, visibility: :public, text: 'With tags #one #two') }

    it 'applies the tags from the status text' do
      expect { subject.call(status) }
        .to change(Tag, :count).by(3)
      expect(status.reload.tags.map(&:name))
        .to contain_exactly('one', 'two', 'nitiasa')
      expect(status.text).to eq 'With tags #one #two'
    end

    it 'removes the default relation when the author opts out' do
      subject.call(status)
      status.update!(text: 'With tags #notag')
      subject.call(status)

      expect(status.reload.tags.map(&:name)).to contain_exactly('notag')
    end

    context 'with a remote post' do
      let(:status) { Fabricate(:status, account: Fabricate(:account, domain: 'remote.example'), text: '<p>Hello</p>') }

      it 'uses only the tags supplied by the remote server' do
        subject.call(status, ['other'])

        expect(status.reload.tags.map(&:name)).to contain_exactly('other')
        expect(status.text).to eq '<p>Hello</p>'
      end
    end
  end
end
