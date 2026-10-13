# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API V1 Statuses Histories' do
  let(:user)  { Fabricate(:user) }
  let(:token) { Fabricate(:accessible_access_token, resource_owner_id: user.id, scopes: scopes) }
  let(:scopes)  { 'read:statuses' }
  let(:headers) { { 'Authorization' => "Bearer #{token.token}" } }

  context 'with an oauth token' do
    describe 'GET /api/v1/statuses/:status_id/history' do
      let(:status) { Fabricate(:status, account: user.account) }

      before do
        get "/api/v1/statuses/#{status.id}/history", headers: headers
      end

      it 'returns http success' do
        expect(response).to have_http_status(200)
        expect(response.content_type)
          .to start_with('application/json')
        expect(response.parsed_body.size).to_not be 0
      end

      context 'with an automatically tagged post edited to opt out' do
        let(:status) do
          PostStatusService.new.call(user.account, text: 'Before', spoiler_text: 'First CW').tap do |status|
            UpdateStatusService.new.call(status, user.account.id, text: 'After #notag', spoiler_text: 'Second CW')
          end
        end

        it 'formats each historical body independently and preserves the raw snapshots' do
          expect(response).to have_http_status(200)
          expect(response.parsed_body.pluck(:content).map { |content| Nokogiri::HTML.fragment(content).text })
            .to eq ['Before #nitiasa', 'After #notag']
          expect(response.parsed_body.pluck(:spoiler_text)).to eq ['First CW', 'Second CW']
          expect(status.edits.ordered.pluck(:text)).to eq ['Before', 'After #notag']
        end
      end
    end
  end
end
