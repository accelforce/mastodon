# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormattingHelper do
  include Devise::Test::ControllerHelpers

  describe '#status_content_format' do
    let(:status) { Fabricate.build(:status, account: Fabricate.build(:account, cat: true), text: 'な 나') }

    it 'preserves authored text by default' do
      expect(helper.status_content_format(status)).to eq '<p>な 나</p>'
    end

    it 'converts local text when requested' do
      expect(helper.status_content_format(status, cat_speech: true)).to eq '<p>にゃ 냐</p>'
      expect(status.text).to eq 'な 나'
    end

    context 'with a remote post' do
      let(:status) { Fabricate.build(:status, account: Fabricate.build(:account, domain: 'example.com', cat: true), text: '<p>な 나</p>') }

      it 'preserves received HTML' do
        expect(helper.status_content_format(status, cat_speech: true)).to eq '<p>な 나</p>'
      end
    end
  end

  describe '#rss_status_content_format' do
    subject { helper.rss_status_content_format(status) }

    context 'with a Cat author' do
      let(:status) { Fabricate(:status, account: Fabricate(:account, cat: true), text: 'な', spoiler_text: 'な', poll: Fabricate.build(:poll, options: ['な', '나'])) }

      it 'converts only the post body' do
        expect(parsed_result.css('p')[1].text).to eq 'にゃ'
        expect(parsed_result.css('p').first.text).to include 'な'
        expect(parsed_result.css('radio').map(&:text)).to eq ['な', '나']
      end
    end

    context 'with a simple status' do
      let(:status) { Fabricate.build :status, text: 'Hello world' }

      it 'renders the formatted elements' do
        expect(parsed_result.css('p').first.text)
          .to eq('Hello world')
      end
    end

    context 'with a spoiler and an emoji and a poll' do
      let(:status) { Fabricate(:status, text: 'Hello :world: <>', spoiler_text: 'This is a spoiler<>', poll: Fabricate.build(:poll, options: %w(Yes<> No))) }

      before { Fabricate :custom_emoji, shortcode: 'world' }

      it 'renders the formatted elements' do
        expect(spoiler_node.css('strong').text)
          .to eq('Content warning:')
        expect(spoiler_node.text)
          .to include('This is a spoiler<>')
        expect(content_node.text)
          .to eq('Hello  <>')
        expect(content_node.css('img').first.to_h.symbolize_keys)
          .to include(
            rel: 'emoji',
            title: ':world:'
          )
        expect(poll_node.css('radio').first.text)
          .to eq('Yes<>')
        expect(poll_node.css('radio').first.to_h.symbolize_keys)
          .to include(
            disabled: 'disabled'
          )
      end

      def spoiler_node
        parsed_result.css('p').first
      end

      def content_node
        parsed_result.css('p')[1]
      end

      def poll_node
        parsed_result.css('p').last
      end
    end

    def parsed_result
      Nokogiri::HTML.fragment(subject)
    end
  end
end
