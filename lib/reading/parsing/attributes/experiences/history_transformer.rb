require_relative "spans_validator"
require_relative "experience_builder"

# TODO Refactor! This entire file has become 🤢🤮 with the accumulation of new
# features in the History column.
#
# Goals of the refactor:
#   - if possible, avoid daily_spans; build spans with date ranges directly.
#   - validate spans at every step; that way the origin of bugs will be easier
#     to find, e.g. for the bug fixed in 6310639, spans became invalid in
#     #fix_open_ranges! and led to an error elsewhere that didn't give a trace
#     back to the origin.
#   - to facilitate the points above, create a class ExperienceBuilder to
#     contain much of the logic that is currently in this file.
module Reading
  module Parsing
    module Attributes
      class Experiences < Attribute
        # Experiences#transform_from_parsed delegates to this class when the
        # History column is not blank (i.e. when experiences should be extracted
        # from History and not the Start Dates, End Dates, and Head columns).
        class HistoryTransformer
          private attr_reader :parsed_row, :head_index

          # @param parsed_row [Hash] a parsed row (the intermediate hash).
          # @param head_index [Integer] current item's position in the Head column.
          def initialize(parsed_row, head_index)
            @parsed_row = parsed_row
            @head_index = head_index
          end

          # Extracts experiences from the parsed row.
          # @return [Array<Hash>] an array of experiences; see
          #   Config#default_config[:item][:template][:experiences]
          def transform
            experiences = parsed_row[:history].map { |entries|
              ExperienceBuilder.new(entries, parsed_row, head_index).to_h
            }

            Experiences::SpansValidator.validate(experiences, history_column: true)

            experiences
          end
        end
      end
    end
  end
end
