# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Channel Subscriptions', :inline_jobs, :streaming do
  let(:application) { Fabricate(:application, confidential: false) }
  let(:scopes) { nil }
  let(:access_token) { Fabricate(:accessible_access_token, resource_owner_id: user_account.user.id, application: application, scopes: scopes) }

  let(:user_account) { Fabricate(:account, username: 'alice', domain: nil) }
  let(:bob_account) { Fabricate(:account, username: 'bob') }

  after do
    streaming_client.close
  end

  context 'when the access token has insufficient scope to read statuses' do
    let(:scopes) { 'profile' }

    it 'cannot subscribe to the public:local channel' do
      streaming_client.authenticate(access_token.token)

      streaming_client.connect
      streaming_client.subscribe('public:local')

      # Receive the error back from the subscription attempt:
      message = streaming_client.wait_for_message

      expect(message).to include(
        error: 'Access token does not have the required scopes',
        status: 401
      )
    end
  end

  context 'when the access token has read scope' do
    let(:scopes) { 'read' }

    it 'keeps community, media, and hashtag subscriptions independent' do
      streaming_client.authenticate(access_token.token)
      streaming_client.connect
      streaming_client.subscribe('public:local')
      streaming_client.subscribe('public:local:media')
      streaming_client.subscribe('hashtag', tag: 'nitiasa')

      media = Fabricate(:media_attachment, account: bob_account)
      status = PostStatusService.new.call(bob_account, text: 'Hello', media_ids: [media.id.to_s])
      messages = Array.new(3) { streaming_client.wait_for_message }

      expect(messages.pluck(:stream)).to contain_exactly(['public:local'], ['public:local:media'], ['hashtag', 'nitiasa'])
      expect(messages.pluck(:payload).pluck(:id)).to all(eq(status.id.to_s))
      expect(messages.pluck(:payload).pluck(:content).map { |content| Nokogiri::HTML.fragment(content).text }).to all(eq('Hello #nitiasa'))
      expect(status.reload.text).to eq 'Hello'
    end

    it 'does not stream posts opting out of the community' do
      streaming_client.authenticate(access_token.token)
      streaming_client.connect
      streaming_client.subscribe('public:local')

      PostStatusService.new.call(bob_account, text: 'Outside the community #notag')
      status = PostStatusService.new.call(bob_account, text: 'In the community')

      expect(streaming_client.wait_for_message).to include(payload: include(id: status.id.to_s))
    end

    it 'filters posts without media from the community media stream' do
      streaming_client.authenticate(access_token.token)
      streaming_client.connect
      streaming_client.subscribe('public:local:media')

      PostStatusService.new.call(bob_account, text: 'Without media')
      media = Fabricate(:media_attachment, account: bob_account)
      status = PostStatusService.new.call(bob_account, text: 'With media', media_ids: [media.id.to_s])

      expect(streaming_client.wait_for_message).to include(payload: include(id: status.id.to_s))
    end

    it 'streams tagged remote posts to the community' do
      streaming_client.authenticate(access_token.token)
      streaming_client.connect
      streaming_client.subscribe('public:local')

      tag = Fabricate(:tag, name: 'nitiasa')
      status = Fabricate(:status, account: Fabricate(:account, domain: 'remote.example'), tags: [tag])
      FanOutOnWriteService.new.call(status)

      expect(streaming_client.wait_for_message).to include(stream: ['public:local'], payload: include(id: status.id.to_s))
    end

    it 'can unsubscribe the community while keeping the hashtag subscription' do
      streaming_client.authenticate(access_token.token)
      streaming_client.connect
      streaming_client.subscribe('public:local')
      streaming_client.subscribe('hashtag', tag: 'nitiasa')

      PostStatusService.new.call(bob_account, text: 'Before unsubscribing')
      2.times { streaming_client.wait_for_message }
      streaming_client.send(JSON.generate(type: 'unsubscribe', stream: 'public:local'))
      status = PostStatusService.new.call(bob_account, text: 'After unsubscribing')

      expect(streaming_client.wait_for_message).to include(stream: ['hashtag', 'nitiasa'], payload: include(id: status.id.to_s))
    end

    it 'can subscribing to the public:local channel' do
      streaming_client.authenticate(access_token.token)

      streaming_client.connect
      streaming_client.subscribe('public:local')

      # We need to publish a status as there is no positive acknowledgement of
      # subscriptions:
      status = PostStatusService.new.call(bob_account, text: 'Hello @alice')

      # And then we want to receive that status:
      message = streaming_client.wait_for_message

      expect(message).to include(
        stream: be_an(Array).and(contain_exactly('public:local')),
        event: 'update',
        payload: include(
          id: status.id.to_s
        )
      )
    end

    it 'can subscribing to the user:notifications channel' do
      streaming_client.authenticate(access_token.token)

      streaming_client.connect
      streaming_client.subscribe('user:notification')

      # We need to perform an action that triggers a notification as there is
      # no positive acknowledgement of subscriptions:
      first_status = PostStatusService.new.call(user_account, text: 'Test')
      ReblogService.new.call(bob_account, first_status)

      message = streaming_client.wait_for_message

      expect(message).to include(
        event: 'notification',
        stream: ['user:notification']
      )
    end
  end

  context 'when the access token has read:statuses scope' do
    let(:scopes) { 'read:statuses' }

    it 'can subscribing to the public:local channel' do
      streaming_client.authenticate(access_token.token)

      streaming_client.connect
      streaming_client.subscribe('public:local')

      # We need to publish a status as there is no positive acknowledgement of
      # subscriptions:
      status = PostStatusService.new.call(bob_account, text: 'Hello @alice')

      # And then we want to receive that status:
      message = streaming_client.wait_for_message

      expect(message).to include(
        stream: be_an(Array).and(contain_exactly('public:local')),
        event: 'update',
        payload: include(
          id: status.id.to_s
        )
      )
    end

    it 'cannot subscribing to the user:notifications channel' do
      streaming_client.authenticate(access_token.token)

      streaming_client.connect
      streaming_client.subscribe('user:notification')

      # We should receive an error back immediately:
      message = streaming_client.wait_for_message

      expect(message).to include(
        error: 'Access token does not have the required scopes',
        status: 401
      )
    end
  end

  context 'when the access token has read:notifications scope' do
    let(:scopes) { 'read:notifications' }

    it 'can subscribing to the user:notifications channel' do
      streaming_client.authenticate(access_token.token)

      streaming_client.connect
      streaming_client.subscribe('user:notification')

      # We need to perform an action that triggers a notification as there is
      # no positive acknowledgement of subscriptions:
      first_status = PostStatusService.new.call(user_account, text: 'Test')
      ReblogService.new.call(bob_account, first_status)

      message = streaming_client.wait_for_message

      expect(message).to include(
        event: 'notification',
        stream: ['user:notification']
      )
    end
  end
end
