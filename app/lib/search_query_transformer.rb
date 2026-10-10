# frozen_string_literal: true

class SearchQueryTransformer < Parslet::Transform
  SUPPORTED_PREFIXES = %w(
    has
    is
    language
    from
    before
    after
    during
    in
  ).freeze

  class Query
    def initialize(clauses, options = {})
      raise ArgumentError if options[:current_account].nil?

      @clauses = clauses
      @options = options

      flags_from_clauses!
    end

    def request
      search = Status.public_visibility.without_reblogs
      search = search.where(library_filter) if @flags['in'] == 'library'

      must_clauses.each { |clause| search = search.where(clause.to_query) }
      must_not_clauses.each { |clause| search = search.where(SearchQueryTransformer.negate(clause.to_query)) }
      filter_clauses.each { |clause| search = search.where(clause.to_query) }

      search
    end

    private

    def clauses_by_operator
      @clauses_by_operator ||= @clauses.compact.group_by(&:operator)
    end

    def flags_from_clauses!
      @flags = clauses_by_operator.fetch(:flag, []).to_h { |clause| [clause.prefix, clause.term] }
    end

    def must_clauses
      clauses_by_operator.fetch(:must, [])
    end

    def must_not_clauses
      clauses_by_operator.fetch(:must_not, [])
    end

    def filter_clauses
      clauses_by_operator.fetch(:filter, [])
    end

    def library_filter
      [<<~SQL.squish, { account_id: @options[:current_account].id }]
        statuses.account_id = :account_id
        OR EXISTS (SELECT 1 FROM mentions WHERE mentions.status_id = statuses.id AND mentions.account_id = :account_id AND NOT mentions.silent)
        OR EXISTS (SELECT 1 FROM favourites WHERE favourites.status_id = statuses.id AND favourites.account_id = :account_id)
        OR EXISTS (SELECT 1 FROM bookmarks WHERE bookmarks.status_id = statuses.id AND bookmarks.account_id = :account_id)
        OR EXISTS (SELECT 1 FROM statuses reblogs WHERE reblogs.reblog_of_id = statuses.id AND reblogs.account_id = :account_id AND reblogs.deleted_at IS NULL)
        OR EXISTS (SELECT 1 FROM poll_votes WHERE poll_votes.poll_id = statuses.poll_id AND poll_votes.account_id = :account_id)
      SQL
    end
  end

  class Operator
    class << self
      def symbol(str)
        case str
        when '+', nil
          :must
        when '-'
          :must_not
        else
          raise "Unknown operator: #{str}"
        end
      end
    end
  end

  class TermClause
    attr_reader :operator, :term

    def initialize(operator, term)
      @operator = Operator.symbol(operator)
      @term = term
    end

    def to_query
      if @term.start_with?('#')
        [<<~SQL.squish, Tag.normalize_value_for(:name, @term.delete_prefix('#'))]
          EXISTS (SELECT 1 FROM statuses_tags INNER JOIN tags ON tags.id = statuses_tags.tag_id
                  WHERE statuses_tags.status_id = statuses.id AND tags.name = ?)
        SQL
      else
        terms = @term.split
        [terms.map { 'statuses.text &@ ?' }.join(' AND '), *terms]
      end
    end
  end

  class PhraseClause
    attr_reader :operator, :phrase

    def initialize(operator, phrase)
      @operator = Operator.symbol(operator)
      @phrase = phrase
    end

    def to_query
      ['statuses.text &@ ?', @phrase]
    end
  end

  class PrefixClause
    EPOCH_RE = /\A\d+\z/

    attr_reader :operator, :prefix, :term

    def initialize(prefix, operator, term, options = {})
      @prefix = prefix
      @negated = operator == '-'
      @options = options
      @operator = :filter

      case prefix
      when 'has', 'is'
        @filter = :properties
        @term = term
      when 'language'
        @filter = :language
        @term = language_code_from_term(term)
      when 'from'
        @filter = :account_id
        @term = account_id_from_term(term)
      when 'before'
        @filter = :created_at
        @term = { lt: date_from_term(term), time_zone: @options[:current_account]&.user_time_zone.presence || 'UTC' }
      when 'after'
        @filter = :created_at
        @term = { gt: date_from_term(term), time_zone: @options[:current_account]&.user_time_zone.presence || 'UTC' }
      when 'during'
        @filter = :created_at
        @term = { gte: date_from_term(term), lte: date_from_term(term), time_zone: @options[:current_account]&.user_time_zone.presence || 'UTC' }
      when 'in'
        @operator = :flag
        @term = term
      else
        raise "Unknown prefix: #{prefix}"
      end
    end

    def to_query
      query = case @filter
              when :properties
                property_query
              when :created_at
                date_query
              else
                ["statuses.#{@filter} = ?", @term]
              end

      @negated ? SearchQueryTransformer.negate(query) : query
    end

    private

    def property_query
      case @term
      when 'reply', 'sensitive'
        ["statuses.#{@term} = TRUE"]
      when 'media', 'image', 'video', 'audio'
        media_query
      when 'poll'
        ['EXISTS (SELECT 1 FROM polls WHERE polls.id = statuses.poll_id)']
      when 'quote'
        ['EXISTS (SELECT 1 FROM quotes WHERE quotes.status_id = statuses.id)']
      when 'link'
        ['EXISTS (SELECT 1 FROM preview_cards_statuses WHERE preview_cards_statuses.status_id = statuses.id)']
      when 'embed'
        [<<~SQL.squish, PreviewCard.types[:video]]
          EXISTS (SELECT 1 FROM preview_cards_statuses INNER JOIN preview_cards ON preview_cards.id = preview_cards_statuses.preview_card_id
                  WHERE preview_cards_statuses.status_id = statuses.id AND preview_cards.type = ?)
        SQL
      else
        ['FALSE']
      end
    end

    def media_query
      query = <<~SQL.squish
        EXISTS (
          SELECT 1 FROM (
            SELECT media_attachments.type FROM media_attachments
            WHERE media_attachments.status_id = statuses.id
              AND (statuses.ordered_media_attachment_ids IS NULL OR media_attachments.id = ANY(statuses.ordered_media_attachment_ids))
            ORDER BY array_position(statuses.ordered_media_attachment_ids, media_attachments.id), media_attachments.id
            LIMIT #{Status::MEDIA_ATTACHMENTS_LIMIT}
          ) media
      SQL

      @term == 'media' ? ["#{query})"] : ["#{query} WHERE media.type = ?)", MediaAttachment.types.fetch(@term)]
    end

    def date_query
      value = @term.values.first
      timestamp = if value.match?(EPOCH_RE)
                    Time.at(Rational(value.to_i, 1000)).utc
                  else
                    Time.find_zone!(@term[:time_zone]).iso8601(value)
                  end
      date_only = !value.match?(EPOCH_RE) && !Date._iso8601(value).key?(:hour)

      case @prefix
      when 'before'
        ['statuses.created_at < ?', timestamp]
      when 'after'
        date_only ? ['statuses.created_at >= ?', timestamp.advance(days: 1)] : ['statuses.created_at > ?', timestamp]
      when 'during'
        date_only ? ['statuses.created_at >= ? AND statuses.created_at < ?', timestamp, timestamp.advance(days: 1)] : ['statuses.created_at = ?', timestamp]
      end
    end

    def account_id_from_term(term)
      return @options[:current_account]&.id || -1 if term == 'me'

      username, domain = term.gsub(/\A@/, '').split('@')
      domain = nil if TagManager.instance.local_domain?(domain)
      account = Account.find_remote(username, domain)

      # If the account is not found, we want to return empty results, so return
      # an ID that does not exist
      account&.id || -1
    end

    def language_code_from_term(term)
      language_code = term

      return language_code if LanguagesHelper::SUPPORTED_LOCALES.key?(language_code.to_sym)

      language_code = term.downcase

      return language_code if LanguagesHelper::SUPPORTED_LOCALES.key?(language_code.to_sym)

      language_code = term.split(/[_-]/).first.downcase

      return language_code if LanguagesHelper::SUPPORTED_LOCALES.key?(language_code.to_sym)

      term
    end

    def date_from_term(term)
      DateTime.iso8601(term) unless term.match?(EPOCH_RE) # This will raise Date::Error if the date is invalid
      term
    end
  end

  def self.negate(query)
    ["(#{query.first}) IS NOT TRUE", *query.drop(1)]
  end

  rule(clause: subtree(:clause)) do
    prefix   = clause[:prefix][:term].to_s.downcase if clause[:prefix]
    operator = clause[:operator]&.to_s
    term     = if clause[:phrase]
                 clause[:phrase].map { |term| term[:term].to_s }.join(' ')
               elsif clause[:shortcode]
                 ":#{clause[:shortcode][:term]}:"
               else
                 clause[:term].to_s
               end

    if clause[:prefix] && SUPPORTED_PREFIXES.include?(prefix)
      PrefixClause.new(prefix, operator, term, current_account: current_account)
    elsif clause[:prefix]
      TermClause.new(operator, "#{prefix} #{term}")
    elsif clause[:term] || clause[:shortcode]
      TermClause.new(operator, term)
    elsif clause[:phrase]
      PhraseClause.new(operator, term)
    else
      raise "Unexpected clause type: #{clause}"
    end
  end

  rule(junk: subtree(:junk)) do
    nil
  end

  rule(query: sequence(:clauses)) do
    Query.new(clauses, current_account: current_account)
  end
end
