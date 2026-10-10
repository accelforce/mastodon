# frozen_string_literal: true

class StatusesSearchService < BaseService
  QUERY_TIMEOUT = ENV.fetch('PGROONGA_QUERY_TIMEOUT', '10s')

  def call(query, account = nil, options = {})
    MastodonOTELTracer.in_span('StatusesSearchService#call') do |span|
      @query   = query&.strip
      @account = account
      @options = options
      @limit   = options[:limit].to_i
      @offset  = options[:offset].to_i
      return [] if @limit.zero?

      span.add_attributes(
        'search.offset' => @offset,
        'search.limit' => @limit,
        'search.backend' => 'pgroonga'
      )

      Status.transaction(requires_new: true) do
        Status.connection.execute("SET LOCAL statement_timeout = #{Status.connection.quote(QUERY_TIMEOUT)}")

        status_search_results.tap do |results|
          span.set_attribute('search.results.count', results.size)
        end
      end
    end
  rescue ActiveRecord::QueryCanceled, Parslet::ParseFailed
    []
  end

  private

  def status_search_results
    request = parsed_query.request.reorder(nil).includes(:account)
    request = request.where(account_id: @options[:account_id]) if @options[:account_id].present?
    request = request.where('statuses.id > ?', @options[:min_id].to_i) if @options[:min_id].present?
    request = request.where(statuses: { id: ...@options[:max_id].to_i }) if @options[:max_id].present?
    results = []
    offset  = @offset

    request.find_in_batches(batch_size: [@limit, 100].max, order: :desc) do |batch|
      @account.preload_relations!(batch.map(&:account_id), batch.map(&:account_domain))

      batch.each do |status|
        next if StatusFilter.new(status, @account).filtered?

        if offset.positive?
          offset -= 1
        else
          results << status
          return results if results.size == @limit
        end
      end
    end

    results
  end

  def parsed_query
    SearchQueryTransformer.new.apply(SearchQueryParser.new.parse(@query), current_account: @account)
  end
end
