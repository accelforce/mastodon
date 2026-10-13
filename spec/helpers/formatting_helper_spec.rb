# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormattingHelper do
  include Devise::Test::ControllerHelpers

  describe '#status_content_format' do
    subject(:formatted_content) { Nokogiri::HTML.fragment(helper.status_content_format(status)) }

    let(:status) { Fabricate.build(:status, text: 'Hello') }

    it 'renders a linked default hashtag without changing the source text' do
      expect(formatted_content.text).to eq 'Hello #nitiasa'
      expect(formatted_content.css('a[rel="tag"]').map(&:text)).to eq ['#nitiasa']
      expect(status.text).to eq 'Hello'
    end

    [
      ['Hello #nitiasa', 'Hello #nitiasa'],
      ['Hello #NITIASA', 'Hello #NITIASA'],
      ['Hello ＃nitiasa', 'Hello #nitiasa'],
      ['Hello #ｎｉｔｉａｓａ', 'Hello #ｎｉｔｉａｓａ'],
      ['Hello #notag', 'Hello #notag'],
      ['Hello #NOTAG', 'Hello #NOTAG'],
      ['Hello #notag #nitiasa', 'Hello #notag #nitiasa'],
    ].each do |text, displayed_text|
      context "with explicitly tagged text: #{text}" do
        let(:status) { Fabricate.build(:status, text: text) }

        it 'does not append another hashtag' do
          expect(formatted_content.text).to eq displayed_text
        end
      end
    end

    %i(unlisted private direct).each do |visibility|
      context "with #{visibility} visibility" do
        let(:status) { Fabricate.build(:status, text: 'Hello', visibility: visibility) }

        it 'renders only the input text' do
          expect(formatted_content.text).to eq 'Hello'
        end
      end
    end

    context 'with a reply' do
      let(:status) { Fabricate.build(:status, text: 'Hello', thread: Fabricate(:status)) }

      it 'renders only the input text' do
        expect(formatted_content.text).to eq 'Hello'
      end
    end

    context 'with a remote post' do
      let(:status) { Fabricate.build(:status, text: '<p>Hello</p>', account: Fabricate(:account, domain: 'remote.example')) }

      it 'preserves the remote content' do
        expect(formatted_content.text).to eq 'Hello'
      end
    end
  end

  describe '#rss_status_content_format' do
    subject { helper.rss_status_content_format(status) }

    context 'with a simple status' do
      let(:status) { Fabricate.build :status, text: 'Hello world' }

      it 'renders the formatted elements' do
        expect(parsed_result.css('p').first.text)
          .to eq('Hello world #nitiasa')
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
          .to eq('Hello  <> #nitiasa')
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
