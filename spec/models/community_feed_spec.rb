# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CommunityFeed do
  subject(:statuses) { described_class.new(viewer, options).get(20) }

  let(:viewer) { Fabricate(:user).account }
  let(:options) { {} }
  let(:tag) { Fabricate(:tag, name: 'nitiasa') }
  let!(:local_status) { Fabricate(:status, tags: [tag], language: 'en') }
  let!(:remote_status) { Fabricate(:status, account: Fabricate(:account, domain: 'remote.example'), tags: [tag], language: 'en') }

  it 'includes local and remote tagged public posts and explicit tagged replies' do
    reply = Fabricate(:status, thread: local_status, tags: [tag])
    Fabricate(:status)
    Fabricate(:status, visibility: :private, tags: [tag])

    expect(statuses).to contain_exactly(local_status, remote_status, reply)
  end

  context 'with media-only selection' do
    let(:options) { { only_media: true } }

    it 'includes only tagged media posts' do
      media_status = Fabricate(:status, tags: [tag], media_attachments: [Fabricate(:media_attachment)])

      expect(statuses).to contain_exactly(media_status)
    end
  end

  context 'when the local live feed is disabled' do
    before { Setting.local_live_feed_access = 'disabled' }

    it 'does not bypass the community access restriction with remote posts' do
      expect(statuses).to be_empty
    end

    context 'with permission to view disabled feeds' do
      let(:viewer) { Fabricate(:moderator_user).account }

      it 'includes the tagged posts' do
        expect(statuses).to contain_exactly(local_status, remote_status)
      end
    end
  end

  context 'when the remote live feed is disabled' do
    before { Setting.remote_live_feed_access = 'disabled' }

    it 'includes only local posts' do
      expect(statuses).to contain_exactly(local_status)
    end
  end

  it 'preserves viewer language preferences' do
    viewer.user.update!(chosen_languages: ['ja'])
    japanese_status = Fabricate(:status, tags: [tag], language: 'ja')

    expect(statuses).to contain_exactly(japanese_status)
  end

  it 'preserves viewer account blocks' do
    viewer.block!(remote_status.account)

    expect(statuses).to contain_exactly(local_status)
  end
end
