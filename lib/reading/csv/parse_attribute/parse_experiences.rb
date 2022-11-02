require_relative "../../errors"
require_relative "../../util/blank"
require_relative "../../util/deep_fetch"

module Reading
  class CSV
    class Row
      class ParseExperiences < ParseAttribute
        using Util::DeepFetch

        def call(_head = nil, columns)
          started, finished = dates_split(columns)
          if @config.deep_fetch(:csv, :reverse_dates)
            started, finished = started.reverse, finished.reverse
          end

          using_dates = started.map.with_index { |entry, i|
            {
              date_added: date_added(entry)                 || template.fetch(:date_added),
              spans: spans(entry, finished, i)              || template.fetch(:spans),
              # date_started:  date_started(entry)            || template.fetch(:date_started),
              # date_finished: date_finished(finished, i)     || template.fetch(:date_finished),
              progress: progress(entry) ||
                progress(columns[:head],
                    ignore_if_no_dnf: i < started.count - 1) || template.fetch(:progress),
              group: group(entry)                           || template.fetch(:group),
              variant_index: variant_index(entry)           || template.fetch(:variant_index)
            }
          }.presence

          if using_dates
            return using_dates
          else
            if prog = progress(columns[:head])
              return [template.merge(progress: prog)]
            else
              return nil
            end
          end
        end

        def template
          @template ||= @config.deep_fetch(:item, :template, :experiences).first
        end

        def dates_split(columns)
          dates_finished = columns[:dates_finished]&.presence
                            &.split(@config.deep_fetch(:csv, :separator)) || []
          # Don't use #has_key? because simply checking for nil covers the
          # case where dates_started is the last column and omitted.
          started_column_exists = columns[:dates_started]&.presence
          dates_started =
            if started_column_exists
              columns[:dates_started]&.presence&.split(@config.deep_fetch(:csv, :separator))
            else
              [""] * dates_finished.count
            end
          [dates_started, dates_finished]
        end

        def date_added(date_entry)
          date_entry.match(@config.deep_fetch(:csv, :regex, :date_added))&.captures&.first
        end

        def spans(date_entry, dates_finished, date_index)
          started = date_started(date_entry)
          finished = date_finished(dates_finished, date_index)
          return [] if started.nil? && finished.nil?

          [{
            dates: started..finished,
            amount: nil,
            description: nil
          }]
        end

        def date_started(date_entry)
          date_entry.match(@config.deep_fetch(:csv, :regex, :date_started))&.captures&.first
        end

        def date_finished(dates_finished, date_index)
          return nil if dates_finished.nil?
          dates_finished[date_index]&.strip&.presence
        end

        def progress(str, ignore_if_no_dnf: false)
          dnf = str.match(@config.deep_fetch(:csv, :regex, :dnf))&.captures&.first

          if dnf || !ignore_if_no_dnf
            captures = str.match(@config.deep_fetch(:csv, :regex, :progress))&.captures
            if captures
              if prog_percent = captures[1]&.to_i
                return prog_percent / 100.0
              elsif prog_time = captures[2]
                return prog_time
              elsif prog_pages = captures[3]&.to_i
                return prog_pages
              end
            end
          end

          return 0 if dnf
          nil
        end

        def group(entry)
          entry.match(@config.deep_fetch(:csv, :regex, :group_experience))&.captures&.first
        end

        def variant_index(date_entry)
          match = date_entry.match(@config.deep_fetch(:csv, :regex, :variant_index))
          (match&.captures&.first&.to_i || 1) - 1
        end
      end
    end
  end
end
