$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "test_helpers/test_helper"

require "reading"

class StatsTest < Minitest::Test
  self.class.attr_reader :queries, :config

  def config = self.class.config

  @config = Reading::Config.new.hash

  # ==== TEST QUERIES

  @queries = {}

  ## QUERIES: OPERATIONS
  # Simple queries testing each operation, without filters or group-by.
  @queries[:operations] = {
    :"average rating" => {
      input: "average rating",
      result: 3.5,
      items: [
        { rating: 3 },
        { rating: 4 },
      ],
    },
    :"average rating with nil" => {
      input: "average rating",
      result: 3.0,
      items: [
        { rating: 3 },
        { rating: nil },
      ],
    },
    :"average length" => {
      input: "average length",
      result: 250,
      items: [
        { variants: [{ length: 200 }], experiences: [{ variant_index: 0 }] },
        { variants: [{ length: 300 }], experiences: [{ variant_index: 0 }] },
      ],
    },
    :"average length with pages and time lengths" => {
      input: "average length",
      result: 180,
      items: [
        { variants: [{ length: 200 }], experiences: [{ variant_index: 0 }] },
        { variants: [{ length: Reading.time("4:00") }], experiences: [{ variant_index: 0 }] },
      ],
    },
    :"average length with time and pages lengths" => {
      input: "average length",
      result: 180,
      items: [
        { variants: [{ length: Reading.time("4:00") }], experiences: [{ variant_index: 0 }] },
        { variants: [{ length: 200 }], experiences: [{ variant_index: 0 }] },
      ],
    },
    :"total items" => {
      input: "total item",
      result: 2,
      items: [
        {},
        {},
      ],
    },
    :"total amount" => {
      input: "total amount",
      result: 47,
      items: [
        { experiences: [{ spans: [{ amount: 20 }] },
                        { spans: [{ amount: 15 }, { amount: Reading.time("0:15") }] }] },
        { experiences: [{ spans: [{ amount: 2 }] }] },
        { experiences: [] },
      ],
    },
    :"top ratings" => {
      input: "top 2 rating",
      result: [["Whoa.", 5], ["Mehhh", 3]],
      items: [
        { title: "Trash", rating: 2 },
        { title: "Mehhh", rating: 3 },
        { title: "Whoa.", rating: 5 },
      ],
    },
    :"top ratings without number arg" => {
      input: "top rating",
      result: Reading::Stats::Operation::DEFAULT_NUMBER_ARG.times.map { ["Better", 3] },
      items: [
        { title: "Trash", rating: 2 },
        *10.times.map { { title: "Better", rating: 3 } },
      ],
    },
    :"top lengths" => {
      input: "top 2 length",
      result: [["Novel", 300], ["Longer", 200]],
      items: [
        { title: "Short", variants: [{ length: 100 }] },
        { title: "Longer", variants: [{ length: Reading.time("5:00") }] },
        { title: "Novel", variants: [{ length: 300 }] },
      ],
    },
    :"bottom ratings" => {
      input: "bottom 2 rating",
      result: [["Trash", 2], ["Mehhh", 3]],
      items: [
        { title: "Trash", rating: 2 },
        { title: "Mehhh", rating: 3 },
        { title: "Whoa.", rating: 5 },
      ],
    },
    :"bottom lengths" => {
      input: "bottom 2 length",
      result: [["Short", 100], ["Longer", 200]],
      items: [
        { title: "Short", variants: [{ length: 100 }] },
        { title: "Longer", variants: [{ length: Reading.time("5:00") }] },
        { title: "Novel", variants: [{ length: 300 }] },
      ],
    },
  }

  # ==== TESTS

  queries[:operations].each do |key, hash|
    define_method("test_operation_#{key}") do
      items = hash.fetch(:items).map { |item_hash|
        Reading::Item.new(
          item_hash,
          config:,
          view: false,
        )
      }

      exp = hash.fetch(:result)
      act = Reading.stats(input: hash.fetch(:input), items:, config:)
      # debugger unless exp == act

      assert_equal exp, act,
        "Unexpected result #{act} from stats query \"#{name}\""

      # Alternate input style: pluralize the second word.
      act = Reading.stats(input: "#{hash.fetch(:input)}s", items:, config:)
      assert_equal exp, act
    end
  end
end
