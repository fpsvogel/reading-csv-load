module Reading
  module Stats
    # The beginning of a query which specifies what it does, e.g.
    # "average rating" or "total amount".
    class Operation
      using Util::NumericToIIfWhole

      # Determines which operation is contained in the given input, and then
      # runs it to get the result. For the operations and their actions, see
      # the constants below.
      # @param input [String] the query string.
      # @param grouped_items [Hash{Symbol => Array<Item>}] if no group was used,
      #   the hash is just { all: items }
      # @param result_formatters [Hash{Symbol => Proc}] to alter the appearance
      #   of results. Keys should be from among the keys of Operation::ACTIONS.
      # @return [Object] the return value of the action; if items are grouped
      #   then a hash is returned with the same keys as grouped_items, otherwise
      #   just the array of all results (not grouped) is returned.
      def self.execute(input, grouped_items, result_formatters)
        REGEXES.each do |key, regex|
          match = input.match(regex)

          if match
            if match[:number_arg]
              number_arg = Integer(match[:number_arg], exception: false) ||
                (raise InputError, "Argument must be an integer. Example: top 5 ratings")
            end

            grouped_results = grouped_items.map { |group_name, items|
              result = ACTIONS[key].call(items, number_arg)

              default_formatter = :itself.to_proc # Just the result itself.
              result_formatter = result_formatters[key] || default_formatter

              [group_name, result_formatter.call(result)]
            }
            .to_h

            if grouped_results.keys == [:all]
              return grouped_results[:all]
            else
              return grouped_results
            end
          end
        end

        raise InputError, "No valid operation in stats query \"#{input}\""
      end

      private

      # The default number argument if one is not given, as in "top ratings"
      # rather than "top 5 ratings".
      DEFAULT_NUMBER_ARG = 10

      # Each action makes some calculation based on the given Items.
      # @param items [Array<Item>]
      # @return [Object] in most cases an Integer.
      ACTIONS = {
        average_rating: proc { |items|
          ratings = items.map(&:rating).compact

          if ratings.any?
            (ratings.sum.to_f / ratings.count).to_i_if_whole
          end
        },
        average_length: proc { |items|
          lengths = items.flat_map { |item|
            item.variants.map(&:length)
          }
          .compact

          if lengths.any?
            (lengths.sum / lengths.count.to_f).to_i_if_whole
          end
        },
        :"average_amount" => proc { |items|
          total_amount = items.sum { |item|
            item.experiences.sum { |experience|
              experience.spans.sum(&:amount)
            }
          }

          (total_amount / items.count.to_f).to_i_if_whole
        },
        :"average_daily-amount" => proc { |items|
          amounts_by_date = calculate_amounts_by_date(items)

          if amounts_by_date.any?
            amounts_by_date.values.sum / amounts_by_date.count
          end
        },
        total_item: proc { |items|
          items.count
        },
        total_amount: proc { |items|
          items.sum { |item|
            item.experiences.sum { |experience|
              experience.spans.sum { |span|
                (span.amount * span.progress).to_i_if_whole
              }
            }
          }
        },
        top_rating: proc { |items, number_arg|
          items
            .max_by(number_arg || DEFAULT_NUMBER_ARG, &:rating)
            .map { |item| [item.title, item.rating] }
        },
        top_length: proc { |items, number_arg|
          items
            .map { |item| [item.title, item.variants.map(&:length).max] }
            .reject { |_title, length| length.nil? }
            .max_by(number_arg || DEFAULT_NUMBER_ARG) { |_title, length| length }
        },
        top_speed: proc { |items, number_arg|
          items
            .map { |item| calculate_speed(item) }
            .compact
            .max_by(number_arg || DEFAULT_NUMBER_ARG) { |_title, speed_hash|
              speed_hash[:amount] / speed_hash[:days].to_f
            }
        },
        bottom_rating: proc { |items, number_arg|
          items
            .min_by(number_arg || DEFAULT_NUMBER_ARG, &:rating)
            .map { |item| [item.title, item.rating] }
        },
        bottom_length: proc { |items, number_arg|
          items
            .map { |item| [item.title, item.variants.map(&:length).max] }
            .reject { |_title, length| length.nil? }
            .min_by(number_arg || DEFAULT_NUMBER_ARG) { |_title, length| length }
        },
        bottom_speed: proc { |items, number_arg|
          items
            .map { |item| calculate_speed(item) }
            .compact
            .min_by(number_arg || DEFAULT_NUMBER_ARG) { |_title, speed_hash|
              speed_hash[:amount] / speed_hash[:days].to_f
            }
        },
      }

      ALIASES = {
        average_rating: %w[ar],
        average_length: %w[al],
        average_amount: %w[aia ai],
        :"average_daily-amount" => %w[ada ad],
        total_item: %w[item count ti],
        total_amount: %w[amount ta],
        top_rating: %w[tr],
        top_length: %w[tl tl],
        top_speed: %w[ts],
        bottom_rating: %w[br],
        bottom_length: %w[bl],
        bottom_speed: %w[bs],
      }

      REGEXES = ACTIONS.map { |key, _action|
        first_word, second_word = key.to_s.split('_')
        aliases = ALIASES.fetch(key)

        regex =
          %r{
            (
              \A
              \s*
              #{first_word}
              s?
              \s*
              (?<number_arg>
                \d+
              )?
              \s*
              (
                #{second_word}
                s?
              )
              \s*
            )
            |
            (
              \A
              \s*
              (#{aliases.join('|')})
              s?
              \s*
              (?<number_arg>
                \d+
              )?
              \s*
            )
          }x

        [key, regex]
      }.to_h

      # Sums the given Items' amounts per date.
      # @param items [Array<Item>]
      # @return [Hash{Date => Numeric, Reading::Item::TimeLength}]
      private_class_method def self.calculate_amounts_by_date(items)
        amounts_by_date = {}

        items.each do |item|
          item.experiences.each do |experience|
            experience.spans.each do |span|
              next unless span.dates

              dates = span.dates.begin..(span.dates.end || Date.today)

              amount = span.amount / dates.count.to_f
              progress = span.members.include?(:progress) ? span.progress : 1.0

              dates.each do |date|
                amounts_by_date[date] ||= 0
                amounts_by_date[date] += amount * progress
              end
            end
          end
        end

        amounts_by_date
      end

      # Calculates an Item's speed (total amount over how many days). Returns
      # nil if a speed is not able to be calculated (e.g. in a planned Item).
      # @param item [Item]
      # @return [Array(String, Hash), nil]
      private_class_method def self.calculate_speed(item)
        speeds = item.experiences.map { |experience|
          spans_with_finite_dates = experience.spans.reject { |span|
            span.dates.nil? || span.dates.end.nil?
          }
          next unless spans_with_finite_dates.any?

          amount = spans_with_finite_dates.sum { |span|
            # Conditional in case Item was created with fragmentary experience hashes,
            # as in stats_test.rb
            progress = span.members.include?(:progress) ? span.progress : 1.0

            span.amount * progress
          }
          .to_i_if_whole

          days = spans_with_finite_dates.sum { |span| span.dates.count }.to_i

          { amount:, days: }
        }
        .compact

        return nil unless speeds.any?

        speed = speeds
          .max_by { |hash| hash[:amount] / hash[:days].to_f }

        [item.title, speed]
      end
    end
  end
end
