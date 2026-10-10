# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AvatarEmoji do
  describe '.from_text' do
    let!(:local_account) { Fabricate(:account, username: 'alice') }
    let!(:remote_account) { Fabricate(:account, username: 'alice', domain: 'remote.example') }

    it 'resolves local and remote references once per shortcode, including adjacent references in HTML' do
      emojis = described_class.from_text('<p>:@alice::@alice@remote.example: :@alice: :@unknown:</p>')

      expect(emojis).to contain_exactly(
        have_attributes(shortcode: '@alice', account: local_account),
        have_attributes(shortcode: '@alice@remote.example', account: remote_account)
      )
    end

    it 'resolves domainless references against the author domain' do
      expect(described_class.from_text(':@alice:', 'remote.example'))
        .to contain_exactly(have_attributes(shortcode: '@alice', account: remote_account))
    end

    it 'resolves explicit local domains and case-insensitive handles' do
      allow(Rails.configuration.x).to receive(:local_domain).and_return('local.example')

      expect(described_class.from_text(':@ALICE@LOCAL.EXAMPLE:'))
        .to contain_exactly(have_attributes(account: local_account))
    end

    it 'ignores blank input and unresolved accounts' do
      expect(described_class.from_text(nil)).to be_empty
      expect(described_class.from_text(':@unknown@unknown.example:')).to be_empty
    end
  end

  describe '#image' do
    subject(:image) { described_class.new(account: account, shortcode: '@alice').image }

    let(:account) { Fabricate.build(:account, avatar_file_name: 'avatar.png', avatar_content_type: 'image/png') }

    it 'uses the original avatar for both image styles when the avatar is static' do
      expect(image.url).to eq(account.avatar_original_url)
      expect(image.url(:static)).to eq(account.avatar_original_url)
    end

    context 'with an animated avatar' do
      let(:account) { Fabricate.build(:account, avatar_file_name: 'avatar.gif', avatar_content_type: 'image/gif') }

      it 'uses the static rendition when requested' do
        expect(image.url).to eq(account.avatar_original_url)
        expect(image.url(:static)).to eq(account.avatar_static_url)
        expect(image.url(:static)).to_not eq(image.url)
      end
    end
  end
end
