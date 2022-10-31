require_relative "../../errors"
require_relative "../../util/deep_fetch"

module Reading
  class CSV
    # A base class that contains behaviors common to Parse___ classes for rows.
    class Row
      using Util::DeepFetch

      def self.from_line(line, config)
        line = line.dup.force_encoding(Encoding::UTF_8).strip

        blank_row = BlankRow.new(config)
        regular_row = RegularRow.new(config)
        compact_planned_row = CompactPlannedRow.new(config)

        case row_type(line, config)
        when :blank, :comment
          blank_row
        when :regular
          regular_row
        when :compact_planned
          return blank_row if config.deep_fetch(:csv, :skip_compact_planned)
          compact_planned_row
        end
      end

      private_class_method def self.row_type(line, config)
        return :blank if line.empty?

        if starts_with_comment_character?(line, config)
          return :compact_planned if compact_planned_row?(line, config)
          return :comment
        end
        :regular
      end

      private_class_method def self.starts_with_comment_character?(line, config)
        line.start_with?(config.deep_fetch(:csv, :comment_character)) ||
          line.match?(/\A\s+#{config.deep_fetch(:csv, :regex, :comment_escaped)}/)
      end

      private_class_method def self.compact_planned_row?(line, config)
        line.match?(config.deep_fetch(:csv, :regex, :compact_planned_row_start))
      end

      def initialize(config)
        @config ||= config
        after_initialize
      end

      # Parses a CSV row into an array of hashes of item data.
      # @param row [String] a CSV row
      # @return [Array<Hash>] an array of hashes like the template in config.rb
      def parse(row)
        before_parse(row)
        titles = []

        items = split_by_format_emojis.map { |name|
          data = item_data(name).then { |data| without_blank_hashes(data) }
          if titles.include?(data[:title])
            raise InvalidItemError, "A title must not appear more than once in the list"
          end
          titles << data[:title]

          data
        }.compact

        items

      rescue InvalidItemError, StandardError => e
        # TODO instead of rescuing StandardError here, test missing
        # initial/middle columns in ParseRegularRow#set_columns, and raise
        # appropriate errors if possible.
        unless e.is_a? InvalidItemError
          if @config.deep_fetch(:errors, :catch_all_errors)
            e = InvalidItemError.new("A row could not be parsed. Check this row")
          else
            raise e
          end
        end

        e.handle(source: row, config: @config)
        []
      ensure
        # Reset to pre-call state.
        initialize(@config)
      end

      private

      def split_by_format_emojis
        multi_items_to_be_split_by_format_emojis
          .split(@config.deep_fetch(:csv, :regex, :formats_split))
          .tap { |names|
            names.first.sub!(@config.deep_fetch(:csv, :regex, :dnf), "")
            names.first.sub!(@config.deep_fetch(:csv, :regex, :progress), "")
          }
          .map { |name| name.strip.sub(/\s*,\z/, "") }
          .partition { |name| name.match?(/\A#{@config.deep_fetch(:csv, :regex, :formats)}/) }
          .reject(&:empty?)
          .first
      end

      # Removes blank arrays of hashes from the given item hash, e.g. series,
      # variants, variants[:sources], and experiences in the template in config.rb.
      # If no parsed data has been added to the template values for these, they
      # are considered blank, and are replaced with an empty array so that their
      # emptiness is more apparent, e.g. data[:experiences].empty? will return true.
      def without_blank_hashes(data_hash, template: @config.deep_fetch(:item, :template))
        data_hash.map { |key, val|
          if is_array_of_hashes?(val)
            if is_blank_like_template?(val, template.deep_fetch(key))
              [key, []]
            else
              [key, val.map { without_blank_hashes(_1, template: template.deep_fetch(key).first) }]
            end
          else
            [key, val]
          end
        }.to_h
      end

      def is_array_of_hashes?(val)
        val.is_a?(Array) && val.first.is_a?(Hash)
      end

      def is_blank_like_template?(val, template_val)
        val.length == 1 && val == template_val
      end

      # Hook, can be overridden.
      def after_initialize
      end

      # Hook, can be overridden.
      def before_parse(row)
      end

      def multi_items_to_be_split_by_format_emojis
        raise NotImplementedError, "#{self.class} should have implemented #{__method__}"
      end

      def item_data(name)
        raise NotImplementedError, "#{self.class} should have implemented #{__method__}"
      end
    end
  end
end
