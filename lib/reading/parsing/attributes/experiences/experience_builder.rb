module Reading
  module Parsing
    module Attributes
      class Experiences < Attribute
        # Experiences#transform_from_parsed delegates to this class when the
        # History column is not blank (i.e. when experiences should be extracted
        # from History and not the Start Dates, End Dates, and Head columns).
        class ExperienceBuilder
          using Util::HashArrayDeepFetch
          using Util::NumericToIIfWhole

          # Rational numbers are used here and in #distribute_amount_across_date_range
          # below so as not to lose precision when dividing a small amount by
          # many days, for example.
          AVERAGE_DAYS_IN_A_MONTH = 30.437r

          private attr_reader :entries, :parsed_row, :head_index, :next_open_range_id

          # @param entries [Array<Hash>] from the parsed row (intermediate hash).
          def initialize(entries, parsed_row, head_index)
            @entries = entries
            @next_open_range_id = 0
            @parsed_row = parsed_row
            @head_index = head_index
          end

          def to_h
            {
              spans: spans_from_history_entries(entries),
              group: entries.first[:group],
              variant_index: (entries.first[:variant] || 1).to_i - 1,
            }
          end

          private

          # A shortcut to the span template.
          # @return [Hash]
          def span_template
            @span_template ||= Config.hash.deep_fetch(:item, :template, :experiences, 0, :spans).first
          end

          # The :spans sub-attribute for the given History column entries.
          # @param entries [Array<Hash>] History entries for one experience.
          # @return [Array<Hash>] an array of spans; see
          #   Config#default_config[:item][:template][:experiences].first[:spans]
          def spans_from_history_entries(entries)
            daily_spans = {}
            active = {
              year: nil,
              month: nil,
              day: nil,
              after_single_date: false,
              open_range_id: nil,
              planned: false,
              amount: nil,
              repetitions: nil,
              frequency: nil,
              last_start_year: nil,
              last_start_month: nil,
            }

            # Dates after "not" entries.
            except_dates = []

            entries.each do |entry|
              if entry[:except_dates]
                except_dates += reject_exception_dates!(entry, daily_spans, active)
                next
              end

              add_to_daily_spans!(entry, daily_spans, active)
            end

            spans = merge_daily_spans(daily_spans)

            spans = fix_open_ranges(spans, except_dates)

            relativize_amounts_from_progress!(spans)

            remove_last_end_date_of_today_if_open_range!(spans)

            remove_temporary_keys!(spans)

            spans
          end

          # Removes the given entry's exception dates from daily_spans.
          # @param entry [Hash] a History entry of exception dates ("not <list of dates>").
          # @param daily_spans [Hash{Array(Date, String) => Hash}] one span per
          #   date-and-name combination.
          # @param active [Hash] variables that persist across entries, such as
          #   amount and implied date.
          # @return [Array<Date>] the rejected dates.
          def reject_exception_dates!(entry, daily_spans, active)
            except_active = {
              year: active[:last_start_year],
              month: active[:last_start_month],
              day: nil,
            }

            except_dates = entry[:except_dates].flat_map { |except_entry|
              start_year = except_entry[:start_year]&.to_i
              start_month = except_entry[:start_month]&.to_i
              # (Start) day is required in an exception date.
              except_active[:day] = except_entry[:start_day].to_i

              # Increment year if month is earlier than previous regular entry's month.
              if except_active[:month] && start_month && start_month < except_active[:month]
                start_year ||= except_active[:year] + 1
              end

              except_active[:year] = start_year if start_year
              except_active[:month] = start_month if start_month

              date_range = date_range(except_entry, except_active)

              date_range&.to_a ||
                Date.new(except_active[:year], except_active[:month], except_active[:day])
            }

            daily_spans.reject! do |(date, _name), _span|
              except_dates.include?(date)
            end

            except_dates
          end

          # Expands the given entry into one span per day, then adds them to daily_spans.
          # @param entry [Hash] a regular History entry (not exception dates).
          # @param daily_spans [Hash{Array(Date, String) => Hash}] one span per
          #   date-and-name combination.
          # @param active [Hash] variables that persist across entries, such as
          #   amount and implied date.
          def add_to_daily_spans!(entry, daily_spans, active)
            start_year = entry[:start_year]&.to_i
            start_month = entry[:start_month]&.to_i
            start_day = entry[:start_day]&.to_i

            # Increment year if start month is earlier than previous entry's month.
            if active[:month] && start_month && start_month < active[:month]
              start_year ||= active[:year] + 1
            end

            active[:year] = start_year if start_year
            active[:last_start_year] = active[:year]
            active[:month] = start_month if start_month
            active[:last_start_month] = active[:month]
            if start_day
              active[:open_range_id] = nil
              active[:day] = start_day
            end

            unless active[:day] && active[:month] && active[:year]
              raise InvalidHistoryError, "Missing or incomplete first date"
            end

            if entry[:planned] || (active[:planned] && !start_day)
              active[:planned] = true
            elsif active[:planned] && start_day
              active[:planned] = false
            end

            duplicate_open_range_id = active[:open_range_id] if !start_day
            date_range = date_range(entry, active, duplicate_open_range: !!duplicate_open_range_id)

            # A startless date range (i.e. with an implied start date) appearing
            # immediately after a single date has its start date bumped forward
            # by one, so that its start date is not the same as the single date.
            if date_range && !start_day && active[:after_single_date]
              date_range = (date_range.begin + 1)..date_range.end
            end
            active[:after_single_date] = !date_range

            variant_index = (entry[:variant_index] || 1).to_i - 1
            format = parsed_row[:sources]&.dig(variant_index)&.dig(:format) ||
              parsed_row[:head][head_index][:format]

            progress = Attributes::Shared.progress(entry)

            amount_from_entry =
              Attributes::Shared.length(entry, format:, key_name: :amount, ignore_repetitions: true)
            amount_from_length =
              Attributes::Shared.length(parsed_row[:length], format:, episodic: progress.nil? || parsed_row.dig(:length, :repetitions).nil?)
            amount = amount_from_entry || amount_from_length
            active[:amount] = amount if amount

            # If the entry has no amount and the item has no episodic length,
            # then use progress as amount instead. The typical scenario for this
            # is when tracking fixed-length items such as books. See
            # https://github.com/fpsvogel/reading/blob/main/doc/csv-format.md#history-pages-and-stopping-points-books
            if !amount && progress
              if progress.is_a? Float
                total_length = Attributes::Shared.length(parsed_row[:length], format:)
                amount = total_length * progress
              else
                amount = progress
              end
              amount_from_progress = true
            end

            repetitions = entry[:repetitions]&.to_i
            frequency = entry[:frequency]

            # If the entry has no amount or progress, default to the previous
            # repetitions and frequency.
            unless amount_from_entry || progress || repetitions
              repetitions = active[:repetitions]
              frequency = active[:frequency]
            end

            active[:repetitions] = repetitions if repetitions
            active[:frequency] = frequency if frequency

            amounts_by_date = distribute_amount_across_date_range(
              date_range || Date.new(active[:year], active[:month], active[:day]),
              amount || active[:amount],
              repetitions || 1,
              frequency,
            )

            open_range_id = active[:open_range_id] || duplicate_open_range_id

            daily_spans_from_entry = amounts_by_date.map { |date, daily_amount|
              span_without_dates = {
                dates: nil,
                amount: daily_amount || span_template[:amount],
                progress: (progress unless amount_from_progress) ||
                  (0.0 if entry[:planned] || active[:planned]) ||
                  span_template[:progress],
                name: entry[:name] || span_template[:name],
                favorite?: !!entry[:favorite] || span_template[:favorite?],
                # Temporary keys (not in the final item data) for marking
                # spans to ...
                # ... be distributed evenly across an open date range.
                open_range_id:,
                # ... have their amounts adjusted to be relative to previous progress.
                amount_from_progress?: amount_from_progress,
                amount_from_frequency?: !!frequency,
                implied_date_range?: !date_range && !!frequency,
              }

              if entry[:planned] || active[:planned]
                date = nil
              end

              key = [date, span_without_dates[:name]]

              # For entries in an open range, add a random number to the key to
              # avoid overwriting entries with the same name, or lacking a name.
              if open_range_id
                key << rand
              end

              [key, span_without_dates]
            }.to_h

            daily_spans.merge!(daily_spans_from_entry)
          end

          # Changes daily spans into normal spans, with chunks of daily spans
          # with contiguous dates compressed into single spans with date ranges.
          # @param daily_spans [Hash{Array(Date, String) => Hash}] one span per
          #   date-and-name combination.
          # @return [Array<Hash>]
          def merge_daily_spans(daily_spans)
            daily_spans
              .chunk_while { |((date_a, _name_a), span_a), ((date_b, _name_b), span_b)|
                date_b && date_a && # in case of planned entry
                  date_b == date_a.next_day &&
                  span_b == span_a
              }.map { |chunked_spans|
                # or chunked_spans.to_h.values.first.first
                span = chunked_spans.first[1]
                first_daily_date = chunked_spans.first[0][0]
                last_daily_date = chunked_spans.last[0][0]

                unless chunked_spans.first[0][0].nil? # in case of planned entry
                  # or chunked_spans.to_h.keys.first[0]..chunked_spans.to_h.keys.last[0]
                  span[:dates] = first_daily_date..last_daily_date
                end

                span[:amount] *= chunked_spans.count

                span
              }.reject { |span|
                span[:amount].zero?
              }
          end

          # Builds the date range for the given entry, if any. Also may update
          # the dates in `active` according to the entry's end date.
          # @param entry [Hash] a History entry.
          # @param active [Hash]variables that persist across entries, such as
          #   amount and implied date.
          # @param duplicate_open_range [Boolean] whether this entry is a
          #   continuation of an open range, in which case it doesn't need to
          #   be a range explicitly.
          # @return [Range<Date>]
          def date_range(entry, active, duplicate_open_range: false)
            return nil unless entry[:range] || duplicate_open_range

            if entry[:end_day]
              active[:open_range_id] = nil

              end_year = entry[:end_year]&.to_i
              end_month = entry[:end_month]&.to_i
              end_day = entry[:end_day].to_i

              # Increment year if end month is earlier than start month.
              if active[:month] && end_month && end_month < active[:month]
                end_year ||= active[:year] + 1
              end

              date_range = Date.new(active[:year], active[:month], active[:day])..
                Date.new(end_year || active[:year], end_month || active[:month], end_day)

              date_after_end = date_range.end.next_day

              active[:day] = date_after_end.day
              active[:month] = date_after_end.month if end_month
              active[:year] = date_after_end.year if end_year
            else # either starting or continuing (duplicating) an open range
              unless active[:open_range_id]
                active[:open_range_id] = next_open_range_id
                @next_open_range_id += 1
              end

              date_range = Date.new(active[:year], active[:month], active[:day])..Date.today
            end

            date_range
          end

          # Distributes an amount across the given date(s).
          # @param date_or_range [Date, Range<Date>] the date or range across
          #   which the amount will be split up.
          # @param amount [Float, Integer, Item::TimeLength] amount in
          #   pages or time.
          # @param repetitions [Integer] e.g. "x4" in a History entry.
          # @param frequency [String] e.g. "/week" in a History entry.
          # @return [Hash{Date => Float, Integer, Item::TimeLength}]
          def distribute_amount_across_date_range(date_or_range, amount, repetitions, frequency)
            unless amount
              raise InvalidHistoryError, "Missing length or amount"
            end

            if date_or_range.is_a? Date
              if frequency
                # e.g. " -- x1/week"
                date_range = date_or_range..Date.today
              else
                date_range = date_or_range..date_or_range
              end
            else
              date_range = date_or_range
            end

            total_amount = amount * repetitions

            case frequency
            when "month"
              months = date_range.count / AVERAGE_DAYS_IN_A_MONTH
              total_amount *= months
            when "week"
              weeks = date_range.count / 7r
              total_amount *= weeks
            when "day"
              days = date_range.count
              total_amount *= days
            end

            days ||= date_range.count
            if days.zero?
              raise InvalidHistoryError,
                "Backward date range in the History column: #{date_range}"
            end

            amount_per_date = (total_amount / days.to_r).to_i_if_whole if total_amount

            amounts_by_date = date_range.to_a.map { |date|
              [date, amount_per_date]
            }.to_h

            amounts_by_date
          end

          # Set each open date range's last end date (wherever it's today, i.e.
          # it wasn't defined) to the day before the next entry's start date.
          # At the same time, distribute each open range's spans evenly.
          # Lastly, remove the :open_range_id key from spans.
          # @param spans [Array<Hash>] spans after being merged from daily_spans.
          # @param except_dates [Date] dates after "not" entries which were
          #   rejected from spans.
          # @return [Array<Hash>]
          def fix_open_ranges(spans, except_dates)
            chunked_by_open_range = spans.chunk_while { |a, b|
              a[:dates] && b[:dates] && # in case of planned entry
                a[:open_range_id] == b[:open_range_id]
            }

            next_start_date = nil
            chunked_by_open_range
              .to_a.reverse.map { |chunk|
                unless chunk.first[:open_range_id]
                  # safe nav. in case of planned entry
                  next_start_date = chunk.first[:dates]&.begin
                  next chunk
                end

                # Filter out spans that begin after the next chunk's start date.
                if next_start_date
                  chunk.reject! do |span|
                    span[:dates].begin >= next_start_date
                  end
                end

                # For the remaining spans (which begin before the next chunk's
                # start date), bound each end date to that date.
                chunk.reverse_each do |span|
                  if !next_start_date
                    next_start_date = span[:dates].begin
                    next
                  end

                  if span[:dates].end >= next_start_date
                    new_dates = span[:dates].begin..next_start_date.prev_day

                    if span[:amount_from_frequency?]
                      new_to_old_dates_ratio = new_dates.count / span[:dates].count.to_f
                      span[:amount] = (span[:amount] * new_to_old_dates_ratio).to_i_if_whole
                    end

                    span[:dates] = new_dates
                  end

                  next_start_date = span[:dates].begin if span[:dates].begin < next_start_date
                end

                if !next_start_date || chunk.first[:dates].begin < next_start_date
                  next_start_date = chunk.first[:dates].begin
                end

                next chunk if chunk.map { |span| span[:open_range_id] }.uniq.count == 1 &&
                  chunk.map { |span| span[:dates].begin }.uniq.count > 1

                # Distribute spans across the open date range.
                total_amount = chunk.sum { |span| span[:amount] }
                dates = chunk.last[:dates]
                amount_per_day = total_amount / dates.count.to_f

                # Save the last end date to restore it after it becomes nil below.
                last_end_date = chunk.last[:dates].end

                span = nil
                chunk_dup = chunk.dup
                amount_acc = 0
                span_needing_end = nil
                dates.each do |date|
                  if span_needing_end && amount_acc < amount_per_day
                    span_needing_end[:dates] = span_needing_end[:dates].begin..date
                    span_needing_end = nil
                  end

                  while amount_acc < amount_per_day
                    break if chunk_dup.empty?
                    span = chunk_dup.shift
                    amount_acc += span[:amount]

                    if amount_acc < amount_per_day
                      end_date = date
                    else
                      end_date = nil
                      span_needing_end = span
                    end

                    span[:dates] = date..end_date
                  end

                  amount_acc -= amount_per_day
                end

                span[:dates] = span[:dates].begin..last_end_date

                chunk
              }
              .reverse
              .flatten
          end

          # Changes amounts taken from progress, from absolute to relative,
          # e.g. at p20 on 2/11 then at p30 on 2/12 (absolute) to
          # 20 pages on 2/11 then 10 pages on 2/12 (relative). Also, remove the
          # :amount_from_progress key key from spans.
          # @param spans [Array<Hash>] spans after being merged from daily_spans.
          # @return [Array<Hash>]
          def relativize_amounts_from_progress!(spans)
            amount_acc = 0
            spans.each do |span|
              if span[:amount_from_progress?]
                span[:amount] -= amount_acc
              end

              amount_acc += span[:amount]
            end
          end

          # Removes the end date from the last span if it's today, and if it was
          # written as an open range.
          # @param spans [Array<Hash>] spans after being merged from daily_spans.
          # @return [Array<Hash>]
          def remove_last_end_date_of_today_if_open_range!(spans)
            if spans.last[:dates] &&
              spans.last[:dates].end == Date.today &&
              (spans.last[:open_range_id] || spans.last[:implied_date_range?])

              spans.last[:dates] = spans.last[:dates].begin..
            end
          end

          # Removes all keys that shouldn't be in the final item data.
          # @param spans [Array<Hash>] spans after being merged from daily_spans.
          # @return [Array<Hash>]
          def remove_temporary_keys!(spans)
            temporary_keys = %i[
              open_range_id
              amount_from_progress?
              amount_from_frequency?
              implied_date_range?
            ]

            spans.each do |span|
              temporary_keys.each do |key|
                span.delete(key)
              end
            end
          end
        end
      end
    end
  end
end
