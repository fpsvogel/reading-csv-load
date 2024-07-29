$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "test_helpers/test_helper"

require "reading"

class ParseTest < Minitest::Test
  using Reading::Util::HashDeepMerge
  using Reading::Util::HashArrayDeepFetch

  self.class.attr_reader :inputs, :outputs

  def inputs = self.class.inputs

  def outputs = self.class.outputs

  # Reset config after every test to undo any custom config from the test.
  def teardown = Reading::Config.build

  # ==== INPUT

  @inputs = {}

  ## INPUT: ENABLING COLUMNS
  # In the columns tests, the input in the heredocs below are each parsed with
  # only the columns enabled that are listed in the hash key. This tests basic
  # functionality of each column, and a few possible combinations of columns.
  @inputs[:enabled_columns] = {}

  @inputs[:enabled_columns][:"head"] = <<~EOM.freeze
    \\Author - Title
    Sapiens
    Goatsong
    How To
  EOM
  @inputs[:enabled_columns][:"head, end_dates"] = <<~EOM.freeze
    \\Author - Title|End dates
    Sapiens
    Goatsong|2020/5/30
    How To
  EOM
  @inputs[:enabled_columns][:"head, start_dates"] = <<~EOM.freeze
    Sapiens|2021/9/1
    Goatsong|2020/5/1
    How To
  EOM
  @inputs[:enabled_columns][:"head, start_dates, end_dates"] = <<~EOM.freeze
    Sapiens|2021/9/1
    Goatsong|2020/5/1|2020/5/30
    How To
  EOM
  @inputs[:enabled_columns][:"rating, head, start_dates, end_dates"] = <<~EOM.freeze
    |Sapiens|2021/9/1
    5|Goatsong|2020/5/1|2020/5/30
    |How To
  EOM
  # length but no sources
  @inputs[:enabled_columns][:"rating, head, start_dates, end_dates, length"] = <<~EOM.freeze
    |Sapiens|2021/9/1||15:17
    5|Goatsong|2020/5/1|2020/5/30|247
    |How To
  EOM
  # sources but no length
  @inputs[:enabled_columns][:"rating, head, sources, start_dates, end_dates"] = <<~EOM.freeze
    |Sapiens|Vail Library B00ICN066A|2021/9/1
    5|Goatsong|0312038380|2020/5/1|2020/5/30
    |How To
  EOM
  # sources and length
  @inputs[:enabled_columns][:"rating, head, sources, start_dates, end_dates, length"] = <<~EOM.freeze
    |Sapiens|Vail Library B00ICN066A|2021/9/1||15:17
    5|Goatsong|0312038380|2020/5/1|2020/5/30|247
    |How To
  EOM



  ## INPUT: FEATURES OF SINGLE COLUMNS
  # In each the features tests, a single column is enabled (specified in the
  # hash key) and a bunch of possible content for that column is tested. These
  # are the columns that are more flexible and can have lots of information
  # crammed into them.
  @inputs[:features_head] =
  {
  :"author" =>
    "Tom Holt - Goatsong",
  :"series" =>
    "Tom Holt - Goatsong -- in The Walled Orchard",
  :"series with volume" =>
    "Tom Holt - Goatsong -- The Walled Orchard, #1",
  :"multiple series" =>
    "Tom Holt - Goatsong -- in Holt Historical Fiction -- The Walled Orchard, #1",
  :"extra info" =>
    "Tom Holt - Goatsong -- paperback -- 1990",
  :"extra info and series" =>
    "Tom Holt - Goatsong -- paperback -- The Walled Orchard, #1 -- 1990",
  :"format" =>
    "📕Tom Holt - Goatsong",
  :"multi items" =>
    "📕Tom Holt - Goatsong, 🔊Sapiens",
  :"multi items without a comma" =>
    "📕Tom Holt - Goatsong 🔊Sapiens",
  :"multi items with a long separator" =>
    "📕Tom Holt - Goatsong -- 🔊Sapiens",
  :"progress" =>
    "50% 📕Tom Holt - Goatsong",
  :"progress pages" =>
    "p220 📕Tom Holt - Goatsong",
  :"progress pages without p" =>
    "220 📕Tom Holt - Goatsong",
  :"progress time" =>
    "2:30 📕Tom Holt - Goatsong",
  :"dnf in head" =>
    "DNF 📕Tom Holt - Goatsong",
  :"other string in head is ignored" =>
    "maybe will DNF 📕Tom Holt - Goatsong",
  :"dnf in head with progress" =>
    "DNF 50% 📕Tom Holt - Goatsong",
  :"dnf with multi items" =>
    "DNF 📕Tom Holt - Goatsong, 🔊Sapiens",
  :"all features" =>
    "DNF 50% 📕Tom Holt - Goatsong -- paperback -- The Walled Orchard, #1 -- 1990, 🔊Sapiens"
  }

  # DEFAULT_TITLE (plus a column separator) are added to the beginning of each
  # input string in the features included in INPUTS_WITH_DEFAULT_TITLE, except
  # in input strings where a custom Head column is provided.
  # This is to avoid having to include a Head column in every input string below,
  # since the Head column is not optional.
  DEFAULT_TITLE = "Default"
  INPUTS_WITH_DEFAULT_TITLE = [
    :features_sources,
    :features_start_dates,
    :features_history,
    :"features_length, history"
  ]

  @inputs[:features_sources] =
  {
  :"ISBN-10" =>
    "0312038380",
  :"ISBN-13" =>
    "978-0312038380",
  :"ASIN" =>
    "B00GVG01HE",
  :"source" =>
    "Little Library",
  :"URL source" =>
    "https://www.edlin.org/holt",
  :"URL source with a name from config" =>
    "https://archive.org/details/walledorchard0000holt",
  :"multiple sources must be separated with commas" =>
    "Little Library, https://www.edlin.org/holt, https://tomholt.com, Lexpub",
  :"source with ISBN" =>
    "Little Library 0312038380",
  :"source with ISBN-10 ending in X" =>
    "Little Library 031203838X",
  :"sources with ISBN" =>
    "Little Library, https://www.edlin.org/holt, https://tomholt.com, Lexpub 0312038380",
  :"comma not required before and after URL source" =>
    "Little Library https://www.edlin.org/holt https://tomholt.com Lexpub 0312038380",
  :"simple variants" =>
    "📕Little Library 📕Lexpub",
  :"variant with extra info" =>
    "📕Little Library -- paperback -- 1990 🔊Lexpub",
  :"optional long separator can be added between variants" =>
    "📕Little Library -- paperback -- 1990 🔊Lexpub",
  :"variant with extra info and series" =>
    "📕Little Library -- paperback -- The Walled Orchard, #1 -- 1990 🔊Lexpub",
  :"variant with extra info and series from Head also" =>
    "#{DEFAULT_TITLE} -- in Holt's Classical Novels -- unabridged|📕Little Library -- paperback -- The Walled Orchard, #1 -- 1990 🔊Lexpub",
  :"length after sources ISBN and before extra info" =>
    "📕Little Library 0312038380 247 -- paperback -- 1990 🔊Lexpub 7:03",
  :"multiple sources allowed in variant" =>
    "📕Little Library, https://www.edlin.org/holt, https://tomholt.com, Lexpub 0312038380 247 -- paperback -- 1990 🔊Lexpub 7:03",
  :"optional commas can be added within and between variants" =>
    "📕Little Library, https://www.edlin.org/holt, https://tomholt.com, Lexpub, 0312038380, 247 -- paperback -- 1990, 🔊Lexpub 7:03",
  }

  @inputs[:features_start_dates] =
  {
  :"start date" =>
    "2020/09/01",
  :"start dates" =>
    "2020/09/01, 2021/07/15",
  :"planned after a start date" =>
    "2020/09/01, ??",
  :"planned only" =>
    "??",
  :"progress" =>
    "50% 2020/09/01",
  :"progress pages" =>
    "220p 2020/09/01",
  :"progress pages without p" =>
    "220 2020/09/01",
  :"progress time" =>
    "2:30 2020/09/01",
  :"dnf default zero" =>
    "DNF 2020/09/01",
  :"dnf with progress" =>
    "DNF 50% 2020/09/01",
  :"dnf only" =>
    "DNF 50%",
  :"variant" =>
    "2020/09/01 v2",
  :"variant only" =>
    "v2",
  :"group" =>
    "2020/09/01 v2 🤝🏼 county book club",
  :"group only" =>
    "🤝🏼 county book club",
  :"all features" =>
    "DNF 50% 2020/09/01 v2, 2:30 2021/07/15",
  }

  # The compact_planned part (unlike in other :features_x) is merely semantic;
  # it has no effect in set_config_columns below.
  @inputs[:features_compact_planned] =
  {
  :"title only" =>
    "\\⚡A Song for Nero",
  :"with author" =>
    "\\⚡Tom Holt - A Song for Nero",
  :"with sources" =>
    "\\⚡Tom Holt - A Song for Nero @Lexpub @Hoopla",
  :"with sources in the Sources column" =>
    "\\⚡Tom Holt - A Song for Nero|Lexpub, Hoopla",
  :"with Sources and Length column" =>
    "\\⚡Tom Holt - A Song for Nero|Lexpub, Hoopla|239",
  :"with only Length column" =>
    "\\⚡Tom Holt - A Song for Nero|239",
  :"with fuller Head and Sources columns" =>
    "\\⚡Tom Holt - A Song for Nero -- unabridged -- in Holt's Classical Novels|Lexpub, Hoopla B00GW4U2TM",
  :"with sources and extra info" =>
    "\\⚡Tom Holt - A Song for Nero @Lexpub @Hoopla -- unabridged -- in Holt's Classical Novels",
  :"multiple" =>
    "\\⚡Tom Holt - A Song for Nero @Lexpub @Hoopla 🔊True Grit @Lexpub",
  :"multiple with source" =>
    "\\@Lexpub: ⚡Tom Holt - A Song for Nero @Hoopla 🔊True Grit",
  :"multiple with genre" =>
    "\\HISTORICAL FICTION: ⚡Tom Holt - A Song for Nero @Lexpub @Hoopla 🔊True Grit @Lexpub",
  :"multiple with multiple genres" =>
    "\\HISTORICAL FICTION, FAVES: ⚡Tom Holt - A Song for Nero @Lexpub @Hoopla 🔊True Grit @Lexpub",
  :"multiple with genre plus source" =>
    "\\HISTORICAL FICTION @Lexpub: ⚡Tom Holt - A Song for Nero @Hoopla 🔊True Grit",
  :"duplicate sources are ignored" =>
    "\\HISTORICAL FICTION @Lexpub: ⚡Tom Holt - A Song for Nero @Hoopla @Lexpub @Hoopla 🔊True Grit @Lexpub",
  :"multiple sources at the beginning" =>
    "\\HISTORICAL FICTION @Lexpub @https://www.lexpublib.org: ⚡Tom Holt - A Song for Nero 🔊True Grit",
  :"config-defined emojis are ignored" =>
    "\\❓HISTORICAL FICTION @Lexpub:⚡💲Tom Holt - A Song for Nero ✅@Hoopla ✅🔊True Grit",
  }

  @inputs[:features_history] =
  {
  :"dates" =>
    "2021/12/6 0:30 -- 12/21 -- 3/1",
  :"dates can omit unchanged month" =>
    "2021/12/6 0:30 -- 21 -- 3/1",
  :"date ranges" =>
    "2021/12/6..8 0:30 -- 12/21 -- 3/1",
  :"adjacent dates of same daily amount are merged into a range" => # of 12/6..10
    "2021/12/6..8 1:30 -- 12/9 0:30 -- 12/10",
  :"time amounts" =>
    "2021/12/6..8 0:35 -- 12/21 0:45 -- 3/1 0:45",
  :"implied time amount" => # 3/1 has an implied amount of 0:45
    "2021/12/6..8 0:35 -- 12/21 0:45 -- 3/1",
  # Here 0:45 has an implied date of 12/9, and 0:30 also has an implied date of
  # 12/9 (the implied date doesn't increment except after a range), so the 0:30
  # overwrites the 0:45 on 12/9.
  :"implied dates" =>
    "2021/12/6..8 0:35 -- 0:45 -- 0:30",
  :"implied date range starts" => # same as 12/6, 12/7..8, 12/9..10
    "2021/12/6 0:35 -- ..12/8 0:45 -- ..12/10 0:25",
  :"implied date range end" =>
    "2021/12/6 0:35 -- 12/7.. 0:45 -- 12/9..10 0:25",
  :"implied date range end today" => # Date.today becomes the end date
    "2021/12/6.. 0:35",
  :"implied date range start and end" => # same as 12/6, 12/7..
    "2021/12/6 0:35 -- .. 0:45",
  :"open range" =>
    "2021/12/6.. 0:35 -- 0:25 -- ..12/13",
  :"open range with repeated name (re-listen)" =>
    "2021/12/6.. 0:35 #1 -- 0:25 #2 -- ..12/13 #1",
  :"open range with dates in the middle" =>
    "2021/12/6.. 0:35 -- 0:25 -- 12/9..10 0:45 -- ..13",
  :"open range with implied end" => # implies ..12/8 0:25
    "2021/12/6.. 0:35 -- 0:25 -- 12/9..10 0:45",
  :"repetition" =>
    "2021/12/6 0:30 x4 -- 12/7 x2",
  :"frequency" =>
    "2021/12/6..6/1 0:30 x1/month",
  :"frequency x1 implied" =>
    "2021/12/6..6/1 0:30/month",
  :"frequency until present" =>
    "2021/12/6..6/1 0:30/month -- .. x2/month",
  :"frequency implied until present" =>
    "2021/12/6..6/1 0:30/month -- x2/month",
  :"previous repetition and frequency apply when amount and progress are omitted" =>
    "2021/12/6..6/1 0:30 x2/month -- 7/1..12/25",
  :"previous frequency does not apply for a new repetition" =>
    "2021/12/6..6/1 0:30 x2/month -- 7/1..12/25 x100",
  :"exception list" =>
    "2021/12/27..1/8 1:00/day -- not 12/28..29, 1/1, ",
  :"exception list after open range" =>
    "2022/9/21.. 1p/day -- not 9/23..24",
  :"open range interrupted by exception" =>
    "2020/1/1.. 1:00 x1/day -- not 1/3..1/4 -- 1/7..1/12 x2/day -- not 1/9..1/10",
  :"open range interrupted by exception, alias" =>
    "2020/1/1..1/6 1:00 x1/day -- not 1/3..1/4 -- ..1/12 x2/day -- not 1/9..1/10",
  :"exception list can be an open range at the end" =>
    "2022/09/24.. 1:00/day -- not 9/25..26 -- 9/28.. 2:00/day -- not 9/30..",
  # 13:00 here gives the same result as 1:00/day, though it's unexpected. We
  # would expect that over these 10 days (not counting the exception days),
  # 10:00 means 1:00/day. However, the amounts are distributed across the days
  # *before* the exception days are removed, i.e. 13:00 across 13 days means
  # 1:00/day. I don't use exception lists with fixed amounts, so I don't feel it
  # would be worth the extra complexity to make exception lists recalculate
  # amount-per-day in cases of a fixed amount. So this is a feature, not a bug ;)
  :"exception list doesn't work as expected with fixed amount" =>
    "2021/12/27..1/8 13:00 -- not 12/28..29, 1/1",
  :"overwriting" =>
    "2021/12/27..1/8 1:00/day -- not 12/28..29, 1/1 -- (1/4..8 2:00/day)",
  :"overwriting can omit parentheses" =>
    "2021/12/27..1/8 1:00/day -- not 12/28..29, 1/1 -- 1/4..8 2:00/day",
  :"overwriting can't omit previous month/year" =>
    "2021/12/27..1/8 1:00/day -- not 12/28..29, 1/1 -- 2021/12/30..31 2:00/day",
  :"overwriting to zero has the same effect" =>
    "2021/12/27..1/8 1:00/day -- (2021/12/28..29 x0) -- (1/1 x0) -- 1/4..8 2:00/day",
  :"names" =>
    "2021/12/6..8 0:35 #1 Why Ruby2JS is a Game Changer -- 12/21 0:45 #2 Componentized View Architecture FTW! -- 3/1 #3 String-Based Templates vs. DSLs",
  :"repeated name means re-listen" =>
    "2021/12/6..8 0:35 #1 Why Ruby2JS is a Game Changer -- 12/21 0:45 #2 Componentized View Architecture FTW! -- 3/1 #3 String-Based Templates vs. DSLs -- 5/1 0:35 #1 Why Ruby2JS is a Game Changer",
  :"favorites" =>
    "2021/12/6..8 0:35 ⭐#1 Why Ruby2JS is a Game Changer -- 12/21 0:45 ⭐#2 Componentized View Architecture FTW! -- 3/1 #3 String-Based Templates vs. DSLs",
  :"multiple experiences" =>
    "2021/12/6 0:30 ---- 2022/4/1 0:30",
  :"variant" =>
    "2021/12/6 0:30 ---- v2 2022/4/1 0:30",
  :"group" =>
    "2021/12/6 0:30 ---- 🤝🏼with Sam 2022/4/1 0:30",
  :"planned" =>
    "2021/12/6..8 0:35 #1 Why Ruby2JS is a Game Changer -- 12/21 0:45 #2 Componentized View Architecture FTW! -- ?? #3 String-Based Templates vs. DSLs",
  :"planned in middle" =>
    "2021/12/6..8 0:35 #1 Why Ruby2JS is a Game Changer -- ?? 0:45 #2 Componentized View Architecture FTW! -- #3 String-Based Templates vs. DSLs -- 4/18 #4 Design Patterns on the Frontend",
  :"DNF" =>
    "2021/12/6..8 DNF 50% 0:35 #1 Why Ruby2JS is a Game Changer -- 12/21 DNF @0:15 0:45 #2 Componentized View Architecture FTW! -- 3/1 DNF 0:45 #3 String-Based Templates vs. DSLs",
  :"progress without DNF" =>
    "2021/12/6..8 50% 0:35 #1 Why Ruby2JS is a Game Changer -- 12/21 @0:15 0:45 #2 Componentized View Architecture FTW! -- 3/1 @0 0:45 #3 String-Based Templates vs. DSLs",
  :"pages amount" =>
    "2021/04/28 10p",
  :"pages amount without p" =>
    "2021/04/28 10",
  :"stopping points in place of amount" =>
    "2021/04/28 10p -- 4/30 @20p -- 5/1 @30p",
  :"stopping point with p on other side or omitted" =>
    "2021/04/28 10p -- 4/30 @p20 -- 5/1 @30",
  }



  @inputs[:"features_length, history"] =
  {
  :"length of each" =>
    "0:30 each|2021/12/6 -- 12/21 0:45 -- 3/1",
  :"repetitions in length" =>
    "0:30 x3|2021/12/6 -- 12/21 -- 3/1",
  :"repetitions in length with 'each'" =>
    "0:30 each x3|2021/12/6 -- 12/21 -- 3/1",
  :"progress makes repetitions in length count as total" =>
    "0:30 x3|2021/12/6 10% -- 12/21 30% -- 3/1 done",
  :"done shortcut with length" =>
    "144|2021/04/28 10p -- 4/30 @20p -- 5/1 @30p -- ..5/20 done",
  }


  ## INPUT: ALL COLUMNS
  # For interactions between columns that are not caught in the single-column
  # tests above. Also for realistic examples from the reading.csv template:
  # https://github.com/fpsvogel/reading/blob/main/doc/reading.csv
  @inputs[:all_columns] =
  {
    :"empty Sources column doesn't prevent variant from elsewhere" =>
      "|📕Sapiens||2020/09/01",
    :"default span amount is the correct length via variants" =>
      "|Goatsong|📕Little Library 0312038380 247 -- paperback -- 1990 🔊Lexpub 7:03|2020/09/01",
  }
  @inputs[:all_columns][:"custom config: listening speed"] = <<~EOM.freeze
    \\{ speed: { format: { audiobook: 1.5, audio: 2 } } }
    |🔊Dracula|||||9:00
    |🎤Flightless Bird|||||||2022/8/1 10:00
  EOM
  @inputs[:all_columns][:"realistic examples: in progress books"] = <<~EOM.freeze
    \\Rating|Format, Author, Title|Sources, ISBN/ASIN|Start dates, Progress|End dates|Genres|Length|Notes|History
    \\------ IN PROGRESS
    |🔊Sapiens: A Brief History of Humankind|Hoopla B00ICN066A|2021/09/20||history|15:17|Easy to criticize, but I like the emphasis on human happiness. -- Ch. 5: "We did not domesticate wheat. It domesticated us." -- Discussion of that point: https://www.reddit.com/r/AskHistorians/comments/2ttpn2
    5|📕Tom Holt - Goatsong|Lexpub 0312038380|2019/05/28, 2020/05/01|2019/06/13|history, fiction|247
  EOM
  @inputs[:all_columns][:"realistic examples: done"] = <<~EOM.freeze
    \\------ DONE
    4|📕Robert Louis Stevenson - Insula Thesauraria -- in Mount Hope Classics -- trans. Arcadius Avellanus|1533694567|2020/10/20 🤝🏼Latin reading group|2021/08/31|latin, fiction|260
    2|DNF 50% 🔊Total Cat Mojo|gift from neighbor Edith B01NCYY3BV|2020/03/21|2020/04/01|cats|10:13|🔒I would've felt bad if I hadn't tried.
    1|DNF 🎤FiveThirtyEight Politics 🎤The NPR Politics Podcast 🎤Pod Save America||2021/08/02|2021/08/02|politics, podcast|0:30|Not very deep. Disappointing.
    5|Randall Munroe - What If?: Serious Scientific Answers to Absurd Hypothetical Questions|🔊Lexpub B00LV2F1ZA 6:36 -- unabridged -- published 2016 ⚡Amazon B00IYUYF4A 320 -- published 2014|2021/08/01, 2021/08/16 v2 🤝🏼with Sam, 2021/09/01|2021/08/15, 2021/08/28, 2021/09/10|science||Favorites: Global Windstorm, Relativistic Baseball, Laser Pointer, Hair Dryer, Machine-Gun Jetpack, Neutron Bullet. -- 💬It's been a long time since I gave highest marks to a "just for fun" book, but wow, this was fun. So fun that after listening to the audiobook, I immediately proceeded to read the book, for its illustrations. If I'd read this as a kid, I might have been inspired to become a scientist.
  EOM
  @inputs[:all_columns][:"realistic examples: planned"] = <<~EOM.freeze
    \\------ PLANNED
    |⚡Tom Holt - Alexander At The World's End|B00GVG00R0|||historical fiction|484
    \\
    \\⚡How to Think Like a Roman Emperor
    \\🔊Trevor Noah - Born a Crime @Lexpub @Jeffco
    \\
    \\HISTORICAL FICTION: ⚡Tom Holt - A Song for Nero 🔊True Grit @Lexpub 🔊Two Gentlemen of Lebowski @https://www.runleiarun.com/lebowski/
    \\SCIENCE, WEIRD @Lexpub: 📕Randall Munroe - How To 🔊Weird Earth @Hoopla
  EOM
  @inputs[:all_columns][:"realistic examples: History column"] = <<~EOM.freeze
    3|🎤Flightless Bird|Spotify, https://armchairexpertpod.com/flightless-bird|||podcast|0:50 each||2021/10/06..11 x23 -- ..12/14 x1/week -- 3/1.. x2/week
    4|🎤Pete Enns & Jared Byas - The Bible for Normal People|https://peteenns.com/podcast|||religion,podcast|||2021/12/01 0:50 #2 Richard Rohr - A Contemplative Look at The Bible -- 12/9 1:30 #19 Megan DeFranza - The Bible and Intersex Believers -- 12/21 ⭐#160 The Risk of an "Errant" Bible -- 0:50 ⭐#164 Where Did Our Bible Come From? -- 1/1 #5 Mike McHargue - Science and the Bible -- ?? #105 Wil Gafney - Womanist Midrash
    4|🎤Escriba Café|https://www.escribacafe.com|||podcast|0:30 each||2021/04/16.. Amor -- Diabolus -- Máfia -- Piratas -- 2:00 Trilogia História do Brasil -- Rapa-Nui -- Espíritos -- Inferno -- ..4/30 Pompeia
    4|🔊Born a Crime|Lexpub B01DHWACVY|||memoir|8:44||2021/5/1 @0:47 -- 5/2 @1:10 -- 5/6..15 0:30/day -- 5/20 @6:50 -- 5/21..23 done
  EOM



  ## INPUT: ERRORS
  # Bad input that should raise an error.
  @inputs[:errors] = {}

  @inputs[:errors][Reading::ParsingError] =
  {
  :"non-numeric rating" =>
    "a|Sapiens",
  :"comment containing a format emoji (matched as compact planned)" =>
    "\\Testing a row with 📕",
  :"ISBN/ASIN before sources" =>
    "|Goatsong|0312038380 Little Library",
  :"OK: ISBN/ASIN as part of a source name" =>
    "|Goatsong|https://archive.org/details/isbn_9780767910422",
  :"date not in yyyy/mm/dd format" =>
    "|Sapiens||2019-01-01|2020/01/01",
  :"start date content without a date" =>
    "|Sapiens||no date here|2020/01/01",
  :"end date content without a date" =>
    "|Sapiens||2019/01/01|no date here",
  :"incomplete date is the same as no date" =>
    "|Sapiens||2019/01|2020/01/01",
  :"conjoined dates" =>
    "|Sapiens||2019/01/01 2020/01/01",
  }
  @inputs[:errors][Reading::InvalidDateError] =
  {
  :"unparsable date" =>
    "|Sapiens||2019/01/32|2020/01/01",
  :"end date before start date" =>
    "|Sapiens||2020/01/01|2019/01/01",
  :"start dates out of order" =>
    "|Sapiens||2019/01/01, 2018/01/01",
  :"end dates out of order" =>
    "|Sapiens||2019/01/01, 2020/01/01|2022/01/01, 2021/01/01",
  :"missing end date" =>
    "|Sapiens||2019/01/01, 2020/01/01|",
  :"missing start date" =>
    "|Sapiens||2019/01/01|2019/03/01, 2020/03/01",
  :"overlapping experiences (end date after the next start date) for the same variant" =>
    "|Sapiens||2019/01/01, 2019/02/01|2019/03/01, ",
  :"OK: overlapping experiences for different variants" =>
    "|Sapiens||2019/01/01, 2019/02/01 v2|2019/03/01, ",
  :"dates out of order in History" =>
    "|Flightless Bird|||||||2021/10/06 0:30 -- 2020/1/1 0:30",
  :"experiences out of order in History" =>
    "|Flightless Bird|||||||2021/10/06 0:30 ---- 2020/1/1 0:30",
  :"overlapping experiences in History" =>
    "|Flightless Bird|||||||2021/10/06..10 0:30 ---- 2021/10/9..12 0:30",
  # Because the second entry overwrites the first one in the overlap.
  :"OK: overlapping date ranges in History" =>
    "|Flightless Bird|||||||2021/10/06..12 0:30 -- 2021/10/10..16 1:00",
  }
  @inputs[:errors][Reading::InvalidHistoryError] =
  {
  :"missing first date" =>
    "|Flightless Bird|||||||0:30",
  :"incomplete first date" =>
    "|Flightless Bird|||||||10/06 0:30",
  :"missing length/amount" =>
    "|Flightless Bird|||||||2021/10/06",
  :"backward date range" =>
    "|Flightless Bird|||||||2021/10/06..5 0:30",
  :"endless date range starts in the future" => # Date::today is stubbed in test_helper.rb to 2022/10/1
    "|Flightless Bird|||||||2022/10/2.. 0:30",
  }
  @inputs[:errors][Reading::InvalidHeadError] =
  {
  :"OK: blank row" =>
    "\n\n",
  :"OK: multiple blank rows" =>
    "\n\n\n\n",
  :"missing Head column" =>
    "2",
  :"blank Head column" =>
    "2| |Hoopla",
  :"missing title" =>
    "|📕 ",
  :"missing title after author" =>
    "|📕Mark Twain - ",
  :"missing title in compact planned row" =>
    "\\📕",
  :"missing title after author in compact planned row" =>
    "\\📕Mark Twain - ",
  }
  @inputs[:errors][Reading::TooManyColumnsError] =
  {
  :"column beyond the number of enabled columns" =>
    "|Sapiens||||||||something",
  :"empty column beyond the number of enabled columns" =>
    "|Sapiens||||||||| ",
  }
  # Examples of bad rows, such as missing columns, that do NOT raise an error.
  # I *could* add more validations to avoid these, but for me these never happen
  # because I view my reading.csv with color-coded columns (Rainbow CSV extension
  # for VS Code). Even so, I'm documenting these odd cases here.
  @inputs[:errors][Reading::Error] =
  {
  :"OK: missing Rating column if the title is numeric (no InvalidRatingError is raised)" =>
    "1984|https://www.george-orwell.org/1984",
  :"OK: missing Head column (the date is parsed as the title)" =>
    "|2019/01/01",
  :"OK: missing Source column (the date is parsed as a source)" =>
    "|Sapiens|2019/01/01",
  :"OK: missing Genres column (the length is parsed as a genre)" =>
    "|Sapiens||2019/01/01|2020/01/01|15:17",
  :"OK: missing Notes column (History is parsed as Notes)" =>
    "|Sapiens||||history|15:17|2022/5/1 p31 -- 5/2 p54 -- 5/6-15 10p -- 5/20 p200 -- 5/21-23 done",
  # OK because in these cases the row is assumed to be a full row.
  :"OK: other columns in a compact planned item when only Sources and Length allowed" =>
    "\\⚡Tom Holt - A Song for Nero|Lexpub, Hoopla|2022/12/21||fiction,history",
  }



  ## INPUT: CUSTOM CONFIG
  # Custom config that should affect the output.
  @inputs[:config] = {
    :"comment_character" =>
      ["#3|Dracula",
        { comment_character: "#" }],
    :"column_separator" =>
      ["$Dracula",
        { column_separator: "$" }],
    :"column_separator can be a tab" =>
      ["\tDracula",
        { column_separator: "\t" }],
    :"skip_compact_planned" =>
      ["\\📕Dracula",
        { skip_compact_planned: true }],
    :"ignored_characters" =>
      ["|✅Dracula",
        { ignored_characters: "Da"}],
    :"listening speed affects Length" =>
      ["|🔊Dracula|||||9:00",
        { speed: { format: { audiobook: 1.5 } } }],
    :"listening speed affects History" =>
      ["|🔊Dracula|||||||2022/8/1 9:00",
        { speed: { format: { audiobook: 1.5 } } }],
  }



  # ==== EXPECTED TEST OUTPUT
  # The results of parsing the above inputs are expected to equal the hashes below.

  def self.item_hash(**partial_hash)
    # This merge is not the same as Reading::Util::HashDeepMerge. This one uses the
    # first (empty) subhashes in the item template, for example in :variants and
    # :experiences in the item template.
    Reading::Config.hash.deep_fetch(:item, :template).merge(partial_hash) do |key, old_value, new_value|
      item_template_merge(key, old_value, new_value)
    end
  end

  def self.item_template_merge(key, old_value, new_value)
    if old_value.is_a?(Array) && old_value.first.is_a?(Hash)
      template = old_value.first
      new_value.map do |v|
        template.merge(v) do |k, old_v, new_v|
          item_template_merge(k, old_v, new_v)
        end
      end
    else
      new_value
    end
  end

  @outputs = {}

  @outputs[:enabled_columns] = {}

  a = item_hash(title: "Sapiens")
  b = item_hash(title: "Goatsong")
  c = item_hash(title: "How To")
  @outputs[:enabled_columns][:"head"] = [a, b, c]

  b_end_only = b.deep_merge(
    experiences: [{ spans: [{ dates: ..Date.new(2020, 5, 30),
                    progress: 1.0}] }],
  )
  @outputs[:enabled_columns][:"head, end_dates"] = [a, b_end_only, c]

  a_start = a.deep_merge(experiences: [{ spans: [{ dates: Date.new(2021, 9, 1).. }] }])
  b_start = b.deep_merge(experiences: [{ spans: [{ dates: Date.new(2020, 5, 1).. }] }])
  @outputs[:enabled_columns][:"head, start_dates"] = [a_start, b_start, c]

  a_start_unfinished = a_start.deep_merge(experiences: [{ spans: [{ progress: 0.0 }] }])
  b_end = item_hash(
    title: "Goatsong",
    experiences: [{ spans: [{ dates: Date.new(2020, 5, 1)..Date.new(2020, 5, 30),
                              progress: 1.0}] }],
  )
  @outputs[:enabled_columns][:"head, start_dates, end_dates"] = [a_start_unfinished, b_end, c]

  a_rating = a_start_unfinished.merge(rating: nil)
  b_rating = b_end.merge(rating: 5)
  @outputs[:enabled_columns][:"rating, head, start_dates, end_dates"] = [a_rating, b_rating, c]

  a_length_and_amount = { variants: [{ length: Reading.time("15:17") }],
                          experiences: [{ spans: [{ amount: Reading.time("15:17") }] }] }
  b_length_and_amount = { variants: [{ length: 247 }],
                          experiences: [{ spans: [{ amount: 247 }] }] }
  a_length = a_rating.deep_merge(a_length_and_amount)
  b_length = b_rating.deep_merge(b_length_and_amount)
  @outputs[:enabled_columns][:"rating, head, start_dates, end_dates, length"] = [a_length, b_length, c]

  a_sources = a_rating.deep_merge(
    variants: [{ isbn: "B00ICN066A",
                 sources: [{ name: "Vail Library" }] }])
  b_sources = b_rating.deep_merge(variants: [{ isbn: "0312038380" }])
  @outputs[:enabled_columns][:"rating, head, sources, start_dates, end_dates"] = [a_sources, b_sources, c]

  a_many = a_sources.deep_merge(a_length_and_amount)
  b_many = b_sources.deep_merge(b_length_and_amount)
  @outputs[:enabled_columns][:"rating, head, sources, start_dates, end_dates, length"] = [a_many, b_many, c]



  @outputs[:features_head] = {}

  a = item_hash(author: "Tom Holt", title: "Goatsong")
  @outputs[:features_head][:"author"] = [a]

  series_name = "The Walled Orchard"
  series = { variants: [{ series: [{ name: series_name }] }] }
  a_series = a.deep_merge(series)
  @outputs[:features_head][:"series"] = [a_series]

  volume = { variants: [{ series: [{ volume: 1 }] }] }
  a_series_volume = a_series.deep_merge(volume)
  @outputs[:features_head][:"series with volume"] = [a_series_volume]

  multi_series = {
    variants: [{ series: [{ name: "Holt Historical Fiction", volume: nil },
                          { name: series_name, volume: 1 }] }],
  }
  a_multi_series = a.deep_merge(multi_series)
  @outputs[:features_head][:"multiple series"] = [a_multi_series]

  extra_info = { variants: [{ extra_info: %w[paperback 1990] }] }
  a_extra_info = a.deep_merge(extra_info)
  @outputs[:features_head][:"extra info"] = [a_extra_info]

  a_extra_info_series = a_extra_info.deep_merge(series).deep_merge(volume)
  @outputs[:features_head][:"extra info and series"] = [a_extra_info_series]

  format = { variants: [{ format: :print }] }
  a_format = a.deep_merge(format)
  @outputs[:features_head][:"format"] = [a_format]

  b = item_hash(title: "Sapiens", variants: [{ format: :audiobook }])
  @outputs[:features_head][:"multi items"] = [a_format, b]

  @outputs[:features_head][:"multi items without a comma"] = [a_format, b]

  @outputs[:features_head][:"multi items with a long separator"] = [a_format, b]

  progress_half = { experiences: [{ spans: [{ progress: 0.5 }] }] }
  a_progress_half = a_format.deep_merge(progress_half)
  @outputs[:features_head][:"progress"] = [a_progress_half]

  progress_pages = { experiences: [{ spans: [{ progress: 220 }] }] }
  a_progress_pages = a_format.deep_merge(progress_pages)
  @outputs[:features_head][:"progress pages"] = [a_progress_pages]

  @outputs[:features_head][:"progress pages without p"] = [a_progress_pages]

  progress_time = { experiences: [{ spans: [{ progress: Reading.time("2:30") }] }] }
  a_progress_time = a_format.deep_merge(progress_time)
  @outputs[:features_head][:"progress time"] = [a_progress_time]

  progress_zero = { experiences: [{ spans: [{ progress: 0 }] }] }
  a_progress_zero = a_format.deep_merge(progress_zero)
  @outputs[:features_head][:"dnf in head"] = [a_progress_zero]

  @outputs[:features_head][:"other string in head is ignored"] = [a_format]

  @outputs[:features_head][:"dnf in head with progress"] = [a_progress_half]

  b_progress_zero = b.deep_merge(experiences: [{ spans: [{ progress: 0 }] }])
  @outputs[:features_head][:"dnf with multi items"] = [a_progress_zero, b_progress_zero]

  full_variants = extra_info.deep_merge(series).deep_merge(volume)
  a_full = a_progress_zero.deep_merge(full_variants).deep_merge(progress_half)
  b_full = b_progress_zero.deep_merge(progress_half)
  @outputs[:features_head][:"all features"] = [a_full, b_full]



  @outputs[:features_sources] = {}

  title = DEFAULT_TITLE
  a = item_hash(title:)
  isbn = "0312038380"
  a_isbn = a.deep_merge(variants: [{ isbn: isbn }])
  @outputs[:features_sources][:"ISBN-10"] = [a_isbn]

  a_isbn_13 = a.deep_merge(variants: [{ isbn: "978-0312038380" }])
  @outputs[:features_sources][:"ISBN-13"] = [a_isbn_13]

  a_asin = a.deep_merge(variants: [{ isbn: "B00GVG01HE" }])
  @outputs[:features_sources][:"ASIN"] = [a_asin]

  library = { name: "Little Library", url: nil }
  a_source = a.deep_merge(variants: [{ sources: [library] }])
  @outputs[:features_sources][:"source"] = [a_source]

  site_1 = { name: nil,
             url: "https://www.edlin.org/holt" }
  a_site_1 = a.deep_merge(variants: [{ sources: [site_1] }])
  @outputs[:features_sources][:"URL source"] = [a_site_1]

  site_named = { name: "Internet Archive",
                 url: "https://archive.org/details/walledorchard0000holt" }
  a_site_named = a.deep_merge(variants: [{ sources: [site_named] }])
  @outputs[:features_sources][:"URL source with a name from config"] = [a_site_named]

  site_2 = { name: nil,
             url: "https://tomholt.com" }
  lexpub = { name: "Lexpub", url: nil }
  three_sources = [library, site_1, site_2, lexpub]
  a_commas = a.deep_merge(variants: [{ sources: three_sources }])
  @outputs[:features_sources][:"multiple sources must be separated with commas"] = [a_commas]

  a_source_isbn = a.deep_merge(
    variants: [{ sources: [library],
                 isbn: isbn }],
  )
  @outputs[:features_sources][:"source with ISBN"] = [a_source_isbn]

  a_source_isbn_x = a_source_isbn.deep_merge(
    variants: [{ isbn: isbn.chop + "X" }],
  )
  @outputs[:features_sources][:"source with ISBN-10 ending in X"] = [a_source_isbn_x]

  a_multi_sources_isbn = a.deep_merge(
    variants: [{ sources: three_sources,
                 isbn: isbn }],
  )
  @outputs[:features_sources][:"sources with ISBN"] = [a_multi_sources_isbn]

  @outputs[:features_sources][:"comma not required before and after URL source"] = [a_multi_sources_isbn]

  a_variants = item_hash(
    title:,
    variants: [{ format: :print, sources: [library] },
               { format: :print, sources: [lexpub] }],
  )
  @outputs[:features_sources][:"simple variants"] = [a_variants]

  a_variant_extra_info = item_hash(
    title:,
    variants: [{ format: :print,
                 sources: [library],
                 extra_info: %w[paperback 1990] },
               { format: :audiobook,
                 sources: [lexpub] }],
  )
  @outputs[:features_sources][:"variant with extra info"] = [a_variant_extra_info]

  @outputs[:features_sources][:"optional long separator can be added between variants"] = [a_variant_extra_info]

  a_variant_series = a_variant_extra_info.deep_merge(
    variants: [{ series: [{ name: "The Walled Orchard", volume: 1 }] }],
  )
  @outputs[:features_sources][:"variant with extra info and series"] = [a_variant_series]

  a_head_extras = a_variant_extra_info.deep_merge(
    variants: [{ series: [{ name: "Holt's Classical Novels", volume: nil },
                          { name: "The Walled Orchard", volume: 1 }],
                 extra_info: %w[unabridged paperback 1990] },
               { series: [{ name: "Holt's Classical Novels", volume: nil }],
                 extra_info: ["unabridged"] }]
  )
  @outputs[:features_sources][:"variant with extra info and series from Head also"] = [a_head_extras]

  a_variant_length = item_hash(
    title:,
    variants: [a_variant_extra_info[:variants].first.merge(isbn: isbn, length: 247),
               a_variant_extra_info[:variants].last.merge(length: Reading.time("7:03"))],
  )
  @outputs[:features_sources][:"length after sources ISBN and before extra info"] = [a_variant_length]

  a_variant_sources = item_hash(
    title:,
    variants: [a_variant_length[:variants].first.merge(sources: three_sources),
               a_variant_length[:variants].last],
  )
  @outputs[:features_sources][:"multiple sources allowed in variant"] = [a_variant_sources]

  @outputs[:features_sources][:"optional commas can be added within and between variants"] = [a_variant_sources]



  @outputs[:features_start_dates] = {}

  a = item_hash(title: DEFAULT_TITLE)
  start = { experiences: [{ spans: [{ dates: Date.new(2020, 9, 1).. }] }] }
  a_start = a.deep_merge(start)
  @outputs[:features_start_dates][:"start date"] = [a_start]

  start_2 = {
    experiences: [{},
                  { spans: [{ dates: Date.new(2021, 7, 15).. }] }],
  }
  a_start_2 = item_hash(**a.deep_merge(start).deep_merge(start_2))
  @outputs[:features_start_dates][:"start dates"] = [a_start_2]

  @outputs[:features_start_dates][:"planned after a start date"] = [a_start]

  @outputs[:features_start_dates][:"planned only"] = [a]

  start_3 = {
    experiences: [{},
                  {},
                  { spans: [{ dates: Date.new(2022, 1, 1).. }] }],
  }
  a_start_3 = item_hash(**a.deep_merge(start).deep_merge(start_2).deep_merge(start_3))
  @outputs[:features_start_dates][:"start dates in any order"] = [a_start_3]

  progress = ->(amount) { { experiences: [{ spans: [{ progress: amount }] }] } }
  a_progress_half = a_start.deep_merge(progress.call(0.5))
  @outputs[:features_start_dates][:"progress"] = [a_progress_half]

  a_progress_pages = a_start.deep_merge(progress.call(220))
  @outputs[:features_start_dates][:"progress pages"] = [a_progress_pages]

  @outputs[:features_start_dates][:"progress pages without p"] = [a_progress_pages]

  a_progress_time = a_start.deep_merge(progress.call(Reading.time("2:30")))
  @outputs[:features_start_dates][:"progress time"] = [a_progress_time]

  a_progress_zero = a_start.deep_merge(progress.call(0))
  @outputs[:features_start_dates][:"dnf default zero"] = [a_progress_zero]

  @outputs[:features_start_dates][:"dnf with progress"] = [a_progress_half]

  a_dnf_only = a.deep_merge(progress.call(0.5))
  @outputs[:features_start_dates][:"dnf only"] = [a_dnf_only]

  variant_2 = { experiences: [{ variant_index: 1 }] }
  a_variant = a_start.deep_merge(variant_2)
  @outputs[:features_start_dates][:"variant"] = [a_variant]

  a_variant_only = a.deep_merge(variant_2)
  @outputs[:features_start_dates][:"variant only"] = [a_variant_only]

  group = { experiences: [{ group: "county book club" }] }
  a_group = a_variant.deep_merge(group)
  @outputs[:features_start_dates][:"group"] = [a_group]

  a_group_only = a.deep_merge(group)
  @outputs[:features_start_dates][:"group only"] = [a_group_only]

  a_start_twice = item_hash(**a.deep_merge(start).deep_merge(start_2))
  a_start_twice_progress = a_start_twice.deep_merge(
    experiences: [{ spans: [{ progress: 0.5 }],
                    variant_index: 1 },
                  { spans: [{ progress: Reading.time("2:30") }] }],
  )
  @outputs[:features_start_dates][:"all features"] = [a_start_twice_progress]



  @outputs[:features_compact_planned] = {}

  a_title = item_hash(title: "A Song for Nero",
                      variants: [{ format: :ebook }])
  @outputs[:features_compact_planned][:"title only"] = [a_title]

  a_author = a_title.merge(author: "Tom Holt")
  @outputs[:features_compact_planned][:"with author"] = [a_author]

  lexpub_and_hoopla = [{ name: "Lexpub", url: nil },
                       { name: "Hoopla", url: nil }]
  a_sources = a_author.deep_merge(variants: [{ sources: lexpub_and_hoopla }])
  @outputs[:features_compact_planned][:"with sources"] = [a_sources]

  @outputs[:features_compact_planned][:"with sources in the Sources column"] = [a_sources]

  a_sources_and_length = a_sources.deep_merge(variants: [{ length: 239 }])
  @outputs[:features_compact_planned][:"with Sources and Length column"] =
    [a_sources_and_length]

  a_length_only = a_author.deep_merge(variants: [{ length: 239 }])
  @outputs[:features_compact_planned][:"with only Length column"] = [a_length_only]

  a_full_sources = a_sources.deep_merge(
    variants: [{ isbn: "B00GW4U2TM",
                 extra_info: ["unabridged"],
                 series: [{ name: "Holt's Classical Novels", volume: nil }] }],
  )
  @outputs[:features_compact_planned][:"with fuller Head and Sources columns"] = [a_full_sources]

  a_full_sources_minus_isbn = a_full_sources.deep_merge(variants: [{ isbn: nil }])
  @outputs[:features_compact_planned][:"with sources and extra info"] = [a_full_sources_minus_isbn]

  b_sources = item_hash(
    title: "True Grit",
    variants: [{ format: :audiobook,
                sources: [{ name: "Lexpub" }] }],
  )
  @outputs[:features_compact_planned][:"multiple"] = [a_sources, b_sources]

  @outputs[:features_compact_planned][:"multiple with source"] = [a_sources, b_sources]

  a_genre = a_sources.merge(genres: ["historical fiction"])
  b_genre = b_sources.merge(genres: ["historical fiction"])
  @outputs[:features_compact_planned][:"multiple with genre"] = [a_genre, b_genre]

  a_multi_genre = a_sources.merge(genres: ["historical fiction", "faves"])
  b_multi_genre = b_sources.merge(genres: ["historical fiction", "faves"])
  @outputs[:features_compact_planned][:"multiple with multiple genres"] = [a_multi_genre, b_multi_genre]

  @outputs[:features_compact_planned][:"multiple with genre plus source"] = [a_genre, b_genre]

  @outputs[:features_compact_planned][:"duplicate sources are ignored"] = [a_genre, b_genre]

  multi_source = [{ sources: [{ name: "Lexpub" },
                              { name: nil, url: "https://www.lexpublib.org" }]}]
  a_multi_source = a_genre.deep_merge(variants: multi_source)
  b_multi_source = b_genre.deep_merge(variants: multi_source)
  @outputs[:features_compact_planned][:"multiple sources at the beginning"] = [a_multi_source, b_multi_source]

  @outputs[:features_compact_planned][:"config-defined emojis are ignored"] = [a_genre, b_genre]



  @outputs[:features_history] = {}

  a_dates = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: Date.new(2021, 12, 6)..Date.new(2021, 12, 6),
        amount: Reading.time("0:30") },
      { dates: Date.new(2021, 12, 21)..Date.new(2021, 12, 21),
        amount: Reading.time("0:30") },
      { dates: Date.new(2022, 3, 1)..Date.new(2022, 3, 1),
        amount: Reading.time("0:30") },
    ] }],
  )
  @outputs[:features_history][:"dates"] = [a_dates]

  @outputs[:features_history][:"dates can omit unchanged month"] = [a_dates]

  a_ranges = a_dates.deep_merge(
    experiences: [{ spans: [
      { dates: Date.new(2021, 12, 6)..Date.new(2021, 12, 8),
        amount: Reading.time("0:30") },
    ] }],
  )
  @outputs[:features_history][:"date ranges"] = [a_ranges]

  a_adjacent = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: Date.new(2021, 12, 6)..Date.new(2021, 12, 10),
        amount: Reading.time("2:30") },
    ] }],
  )
  @outputs[:features_history][:"adjacent dates of same daily amount are merged into a range"] = [a_adjacent]

  a_amounts = a_ranges.deep_merge(
    experiences: [{ spans: [
      { amount: Reading.time("0:35") },
      { amount: Reading.time("0:45") },
      { amount: Reading.time("0:45") },
    ] }],
  )
  @outputs[:features_history][:"time amounts"] = [a_amounts]

  @outputs[:features_history][:"implied time amount"] = [a_amounts]

  a_implied_dates = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: Date.new(2021, 12, 6)..Date.new(2021, 12, 8),
        amount: Reading.time("0:35") },
      { dates: Date.new(2021, 12, 9)..Date.new(2021, 12, 9),
        amount: Reading.time("0:30") },
    ] }],
  )
  @outputs[:features_history][:"implied dates"] = [a_implied_dates]

  a_implied_range_start = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: Date.new(2021, 12, 6)..Date.new(2021, 12, 6),
        amount: Reading.time("0:35") },
      { dates: Date.new(2021, 12, 7)..Date.new(2021, 12, 8),
        amount: Reading.time("0:45") },
      { dates: Date.new(2021, 12, 9)..Date.new(2021, 12, 10),
        amount: Reading.time("0:25") },
    ] }],
  )
  @outputs[:features_history][:"implied date range starts"] = [a_implied_range_start]

  @outputs[:features_history][:"implied date range end"] = [a_implied_range_start]

  a_implied_range_end_today = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: Date.new(2021, 12, 6)..,
        amount: Reading.time("0:35") },
    ] }],
  )
  @outputs[:features_history][:"implied date range end today"] = [a_implied_range_end_today]

  a_implied_range_start_and_end = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: Date.new(2021, 12, 6)..Date.new(2021, 12, 6),
        amount: Reading.time("0:35") },
      { dates: Date.new(2021, 12, 7)..,
        amount: Reading.time("0:45") },
    ] }],
  )
  @outputs[:features_history][:"implied date range start and end"] =
    [a_implied_range_start_and_end]

  a_open_range = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: Date.new(2021, 12, 6)..Date.new(2021, 12, 9),
        amount: Reading.time("0:35") },
      { dates: Date.new(2021, 12, 9)..Date.new(2021, 12, 11),
        amount: Reading.time("0:25") },
      { dates: Date.new(2021, 12, 11)..Date.new(2021, 12, 13),
        amount: Reading.time("0:25") },
    ] }],
  )
  @outputs[:features_history][:"open range"] = [a_open_range]

  a_open_range_with_names = a_open_range.deep_merge(
    experiences: [{ spans: [
      { name: "#1" },
      { name: "#2" },
      { name: "#1" },
    ] }],
  )
  @outputs[:features_history][:"open range with repeated name (re-listen)"] = [a_open_range_with_names]

  a_open_range_dates_in_middle = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: Date.new(2021, 12, 6)..Date.new(2021, 12, 7),
        amount: Reading.time("0:35") },
      { dates: Date.new(2021, 12, 7)..Date.new(2021, 12, 8),
        amount: Reading.time("0:25") },
      { dates: Date.new(2021, 12, 9)..Date.new(2021, 12, 10),
        amount: Reading.time("0:45") },
      { dates: Date.new(2021, 12, 11)..Date.new(2021, 12, 13),
        amount: Reading.time("0:45") },
    ] }],
  )
  @outputs[:features_history][:"open range with dates in the middle"] =
    [a_open_range_dates_in_middle]

  a_open_range_implied_end = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans:
      a_open_range_dates_in_middle.deep_fetch(:experiences, 0, :spans).first(3)
    }],
  )
  @outputs[:features_history][:"open range with implied end"] =
    [a_open_range_implied_end]

  a_repetition = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: Date.new(2021, 12, 6)..Date.new(2021, 12, 6),
        amount: Reading.time("2:00") },
      { dates: Date.new(2021, 12, 7)..Date.new(2021, 12, 7),
        amount: Reading.time("1:00") },
    ] }],
  )
  @outputs[:features_history][:"repetition"] = [a_repetition]

  start_date = Date.new(2021, 12, 6)
  end_date_june = Date.new(2022, 6, 1)
  days_per_month =
    Reading::Parsing::Attributes::Experiences::ExperienceBuilder::AVERAGE_DAYS_IN_A_MONTH
  almost_6_months = (end_date_june - start_date + 1).to_i / days_per_month
  minutes_175 = almost_6_months * 30
  a_frequency = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: start_date..end_date_june,
        amount: Reading::Item::TimeLength.new(minutes_175) },
    ] }],
  )
  @outputs[:features_history][:"frequency"] = [a_frequency]

  @outputs[:features_history][:"frequency x1 implied"] = [a_frequency]

  second_start_date = end_date_june + 1
  # 10 months because Date::today is stubbed in test_helper.rb
  about_4_months = (Date.today - second_start_date + 1).to_i / days_per_month
  minutes_240 = about_4_months * 30 * 2 # multiply by 2 because x2/month this time
  a_frequency_present = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      a_frequency.deep_fetch(:experiences, 0, :spans, 0),
      { dates: second_start_date..,
        amount: Reading::Item::TimeLength.new(minutes_240) },
    ] }],
  )
  @outputs[:features_history][:"frequency until present"] = [a_frequency_present]

  @outputs[:features_history][:"frequency implied until present"] = [a_frequency_present]

  a_frequency_defaulted = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: start_date..end_date_june,
        amount: Reading::Item::TimeLength.new(minutes_175) * 2 },
      { dates: Date.new(2022, 7, 1)..Date.new(2022, 12, 25),
        amount: Reading::Item::TimeLength.new(minutes_175) * 2 },
    ] }],
  )
  @outputs[:features_history][:"previous repetition and frequency apply when amount and progress are omitted"] =
    [a_frequency_defaulted]

  a_frequency_reset = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: start_date..end_date_june,
        amount: Reading::Item::TimeLength.new(minutes_175) * 2 },
      { dates: Date.new(2022, 7, 1)..Date.new(2022, 12, 25),
        amount: Reading::Item::TimeLength.new(3000) },
    ] }],
  )
  @outputs[:features_history][:"previous frequency does not apply for a new repetition"] =
    [a_frequency_reset]

  a_except = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: Date.new(2021, 12, 27)..Date.new(2021, 12, 27),
        amount: Reading.time("1:00") },
      { dates: Date.new(2021, 12, 30)..Date.new(2021, 12, 31),
        amount: Reading.time("2:00") },
      { dates: Date.new(2022, 1, 2)..Date.new(2022, 1, 8),
        amount: Reading.time("7:00") },
    ] }],
  )
  @outputs[:features_history][:"exception list"] = [a_except]

  except_after_open_range = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: Date.new(2022, 9, 21)..Date.new(2022, 9, 22),
        amount: 2 },
      { dates: Date.new(2022, 9, 25)..,
        amount: 7 },
    ] }],
  )

  @outputs[:features_history][:"exception list after open range"] = [except_after_open_range]

  open_range_interrupted = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: Date.new(2020, 1, 1)..Date.new(2020, 1, 2),
        amount: Reading.time("2:00") },
      { dates: Date.new(2020, 1, 5)..Date.new(2020, 1, 6),
        amount: Reading.time("2:00") },
      { dates: Date.new(2020, 1, 7)..Date.new(2020, 1, 8),
        amount: Reading.time("4:00") },
      { dates: Date.new(2020, 1, 11)..Date.new(2020, 1, 12),
        amount: Reading.time("4:00") },
    ] }],
  )

  @outputs[:features_history][:"open range interrupted by exception"] = [open_range_interrupted]

  @outputs[:features_history][:"open range interrupted by exception, alias"] = [open_range_interrupted]

  except_at_end = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: Date.new(2022, 9, 24)..Date.new(2022, 9, 24),
        amount: Reading.time("1:00") },
      { dates: Date.new(2022, 9, 27)..Date.new(2022, 9, 27),
        amount: Reading.time("1:00") },
      { dates: Date.new(2022, 9, 28)..Date.new(2022, 9, 29),
        amount: Reading.time("4:00") },
    ] }],
  )
  @outputs[:features_history][:"exception list can be an open range at the end"] = [except_at_end]

  @outputs[:features_history][:"exception list doesn't work as expected with fixed amount"] = [a_except]

  a_overwriting = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      *a_except.deep_fetch(:experiences, 0, :spans).first(2),
      { dates: Date.new(2022, 1, 2)..Date.new(2022, 1, 3),
        amount: Reading.time("2:00") },
      { dates: Date.new(2022, 1, 4)..Date.new(2022, 1, 8),
        amount: Reading.time("10:00") },
    ] }],
  )
  @outputs[:features_history][:"overwriting"] = [a_overwriting]

  @outputs[:features_history][:"overwriting can omit parentheses"] = [a_overwriting]

  a_explicit_month = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      a_except.deep_fetch(:experiences, 0, :spans).first,
      { dates: Date.new(2021, 12, 30)..Date.new(2021, 12, 31),
        amount: Reading.time("4:00") },
      a_except.deep_fetch(:experiences, 0, :spans).last
    ] }],
  )
  @outputs[:features_history][:"overwriting can't omit previous month/year"] = [a_explicit_month]

  @outputs[:features_history][:"overwriting to zero has the same effect"] = [a_overwriting]

  a_names = a_amounts.deep_merge(
    experiences: [{ spans: [
      { name: "#1 Why Ruby2JS is a Game Changer" },
      { name: "#2 Componentized View Architecture FTW!" },
      { name: "#3 String-Based Templates vs. DSLs" },
    ] }],
  )
  @outputs[:features_history][:"names"] = [a_names]

  a_names_repeat = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      *a_names[:experiences].first[:spans],
      {
        dates: Date.new(2022,5,1)..Date.new(2022,5,1),
        amount: Reading.time("0:35"),
        name: "#1 Why Ruby2JS is a Game Changer",
      },
    ]} ],
  )
  @outputs[:features_history][:"repeated name means re-listen"] = [a_names_repeat]

  a_favorites = a_names.deep_merge(
    experiences: [{ spans: [
      { favorite?: true },
      { favorite?: true },
    ] }],
  )
  @outputs[:features_history][:"favorites"] = [a_favorites]

  a_experiences = item_hash(
    title: DEFAULT_TITLE,
    experiences: [
      { spans: [
        { dates: Date.new(2021, 12, 6)..Date.new(2021, 12, 6),
          amount: Reading.time("0:30") },
      ] },
      { spans: [
        { dates: Date.new(2022, 4, 1)..Date.new(2022, 4, 1),
          amount: Reading.time("0:30") },
      ] },
    ],
  )
  @outputs[:features_history][:"multiple experiences"] = [a_experiences]

  a_variant = a_experiences.deep_merge(
    experiences: [
      { },
      { variant_index: 1 },
    ],
  )
  @outputs[:features_history][:"variant"] = [a_variant]

  a_group = a_experiences.deep_merge(
    experiences: [
      { },
      { group: "with Sam" },
    ],
  )
  @outputs[:features_history][:"group"] = [a_group]

  a_planned = a_names.deep_merge(
    experiences: [{ spans: [
      {},
      {},
      { dates: nil, progress: 0.0 },
    ] }],
  )
  @outputs[:features_history][:"planned"] = [a_planned]

  a_planned_mid = a_names.deep_merge(
    experiences: [{ spans: [
      { },
      { dates: nil, progress: 0.0 },
      { dates: nil, progress: 0.0 },
      { dates: Date.new(2022,4,18)..Date.new(2022,4,18),
        amount: Reading.time("0:45"),
        progress: 1.0,
        name: "#4 Design Patterns on the Frontend",
        favorite?: false },
    ] }],
  )
  @outputs[:features_history][:"planned in middle"] = [a_planned_mid]

  a_dnf = a_names.deep_merge(
    experiences: [{ spans: [
      { progress: 0.5 },
      { progress: Reading.time("0:15") },
      { progress: 0 },
    ] }],
  )
  @outputs[:features_history][:"DNF"] = [a_dnf]

  @outputs[:features_history][:"progress without DNF"] = [a_dnf]

  b_pages = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      { dates: Date.new(2021, 4, 28)..Date.new(2021, 4, 28),
        amount: 10 }
    ] }],
  )
  @outputs[:features_history][:"pages amount"] = [b_pages]

  @outputs[:features_history][:"pages amount without p"] = [b_pages]

  b_stopping_points = item_hash(
    title: DEFAULT_TITLE,
    experiences: [{ spans: [
      b_pages.deep_fetch(:experiences, 0, :spans, 0),
      { dates: Date.new(2021, 4, 30)..Date.new(2021, 4, 30),
        amount: 10 },
      { dates: Date.new(2021, 5, 1)..Date.new(2021, 5, 1),
        amount: 10 },
    ] }],
  )
  @outputs[:features_history][:"stopping points in place of amount"] = [b_stopping_points]

  @outputs[:features_history][:"stopping point with p on other side or omitted"] = [b_stopping_points]



  @outputs[:"features_length, history"] = {}

  a_each = a_dates.deep_merge(
    experiences: [{ spans: [
      { amount: Reading.time("0:30") },
      { amount: Reading.time("0:45") },
      { amount: Reading.time("0:30") },
    ] }],
  )
  @outputs[:"features_length, history"][:"length of each"] = [a_each]

  a_length_repetitions = a_dates.deep_merge(
    variants: [{ length: Reading.time("1:30") }],
    experiences: [{ spans: [
      { amount: Reading.time("0:30") },
      { amount: Reading.time("0:30") },
      { amount: Reading.time("0:30") },
    ] }],
  )
  @outputs[:"features_length, history"][:"repetitions in length"] = [a_length_repetitions]

  @outputs[:"features_length, history"][:"repetitions in length with 'each'"] = [a_length_repetitions]

  a_length_repetitions_as_total = a_dates.deep_merge(
    variants: [{ length: Reading.time("1:30") }],
    experiences: [{ spans: [
      { amount: Reading.time("1:30"), progress: 0.1 },
      { amount: Reading.time("1:30"), progress: 0.3 },
      { amount: Reading.time("1:30"), progress: 1.0 },
    ] }],
  )

  @outputs[:"features_length, history"][:"progress makes repetitions in length count as total"] = [a_length_repetitions_as_total]

  b_done = item_hash(
    title: DEFAULT_TITLE,
    variants: [{ length: 144 }],
    experiences: [{ spans: [
      *b_stopping_points.deep_fetch(:experiences, 0, :spans),
      { dates: Date.new(2021, 5, 2)..Date.new(2021, 5, 20),
        amount: 114 },
    ] }],
  )
  @outputs[:"features_length, history"][:"done shortcut with length"] = [b_done]



  @outputs[:all_columns] = {}

  a = item_hash(title: "Sapiens")
  start = { experiences: [{ spans: [{ dates: Date.new(2020, 9, 1).., progress: 0.0 }] }] }
  a_start = a.deep_merge(start)
  a_start_format = a_start.deep_merge(variants: [{ format: :print }])
  @outputs[:all_columns][:"empty Sources column doesn't prevent variant from elsewhere"] = [a_start_format]

  a_variant_length = item_hash(
    title: "Goatsong",
    variants: [a_variant_extra_info[:variants].first.merge(isbn: isbn, length: 247),
               a_variant_extra_info[:variants].last.merge(length: Reading.time("7:03"))],
  )
  a_variant_length_with_experience =
    a_variant_length.deep_merge(
      experiences: [{
        spans: [{ dates: Date.new(2020, 9, 1).., progress: 0.0, amount: 247 }],
        variant_index: 0
      }]
    )
  @outputs[:all_columns][:"default span amount is the correct length via variants"] = [a_variant_length_with_experience]

  custom_config_a = item_hash(
    title: "Dracula",
    variants: [{ format: :audiobook, length: Reading.time("6:00") }],
  )

  custom_config_b = item_hash(
    title: "Flightless Bird",
    variants: [{ format: :audio }],
    experiences: [{ spans: [{
      dates: Date.new(2022,8,1)..Date.new(2022,8,1),
      amount: Reading.time("5:00"),
    }] }],
  )

  @outputs[:all_columns][:"custom config: listening speed"] = [custom_config_a, custom_config_b]

  sapiens = item_hash(
    title: "Sapiens: A Brief History of Humankind",
    variants:    [{ format: :audiobook,
                    sources: [{ name: "Hoopla" }],
                    isbn: "B00ICN066A",
                    length: Reading.time("15:17") }],
    experiences: [{ spans: [{ dates: Date.new(2021, 9, 20)..,
                              amount: Reading.time("15:17"),
                              progress: 0.0 }] }],
    genres: ["history"],
    notes: [
      { content: "Easy to criticize, but I like the emphasis on human happiness." },
      { content: "Ch. 5: \"We did not domesticate wheat. It domesticated us.\"" },
      { content: "Discussion of that point: https://www.reddit.com/r/AskHistorians/comments/2ttpn2" },
    ],
  )
  goatsong = item_hash(
    rating: 5,
    author: "Tom Holt",
    title: "Goatsong",
    variants:    [{ format: :print,
                    sources: [{ name: "Lexpub" }],
                    isbn: "0312038380",
                    length: 247 }],
    experiences: [{ spans: [{ dates: Date.new(2019, 5, 28)..Date.new(2019, 6, 13),
                              amount: 247,
                              progress: 1.0 }] },
                  { spans: [{ dates: Date.new(2020, 5, 1)..,
                              amount: 247,
                              progress: 0.0 }] }],
    genres: %w[history fiction],
  )
  @outputs[:all_columns][:"realistic examples: in progress books"] = [sapiens, goatsong]

  insula = item_hash(
    rating: 4,
    author: "Robert Louis Stevenson",
    title: "Insula Thesauraria",
    variants:    [{ format: :print,
                    series: [{ name: "Mount Hope Classics" }],
                    isbn: "1533694567",
                    length: 260,
                    extra_info: ["trans. Arcadius Avellanus"] }],
    experiences: [{ spans: [{ dates: Date.new(2020, 10, 20)..Date.new(2021, 8, 31),
                              amount: 260,
                              progress: 1.0 }],
                    group: "Latin reading group" }],
    genres: %w[latin fiction],
  )
  cat_mojo = item_hash(
    rating: 2,
    title: "Total Cat Mojo",
    variants:    [{ format: :audiobook,
                    sources: [{ name: "gift from neighbor Edith" }],
                    isbn: "B01NCYY3BV",
                    length: Reading.time("10:13") }],
    experiences: [{ spans: [{ dates: Date.new(2020, 3, 21)..Date.new(2020, 4, 1),
                              amount: Reading.time("10:13"),
                              progress: 0.5 }] }],
    genres: %w[cats],
    notes: [{ private?: true, content: "I would've felt bad if I hadn't tried." }],
  )
  podcast_1 = item_hash(
    rating: 1,
    title: "FiveThirtyEight Politics",
    variants:    [{ format: :audio,
                    length: Reading.time("0:30") }],
    experiences: [{ spans: [{ dates: Date.new(2021, 8, 2)..Date.new(2021, 8, 2),
                              amount: Reading.time("0:30"),
                              progress: 0 }],
                    variant_index: 0 }],
    genres: %w[politics podcast],
    notes: [{ content: "Not very deep. Disappointing." }],
  )
  podcast_2 = podcast_1.merge(title: "The NPR Politics Podcast")
  podcast_3 = podcast_1.merge(title: "Pod Save America")
  what_if = item_hash(
    rating: 5,
    author: "Randall Munroe",
    title: "What If?: Serious Scientific Answers to Absurd Hypothetical Questions",
    variants:    [{ format: :audiobook,
                    sources: [{ name: "Lexpub" }],
                    isbn: "B00LV2F1ZA",
                    length: Reading.time("6:36"),
                    extra_info: ["unabridged", "published 2016"] },
                  { format: :ebook,
                    sources: [{ name: "Amazon" }],
                    isbn: "B00IYUYF4A",
                    length: 320,
                    extra_info: ["published 2014"] }],
    experiences: [{ spans: [{ dates: Date.new(2021, 8, 1)..Date.new(2021, 8, 15),
                              amount: Reading.time("6:36"),
                              progress: 1.0 }],
                    variant_index: 0 },
                  { spans: [{ dates: Date.new(2021, 8, 16)..Date.new(2021, 8, 28),
                              amount: 320,
                              progress: 1.0 }],
                    group: "with Sam",
                    variant_index: 1 },
                  { spans: [{ dates: Date.new(2021, 9, 1)..Date.new(2021, 9, 10),
                              amount: Reading.time("6:36"),
                              progress: 1.0 }],
                    variant_index: 0 }],
    genres: %w[science],
    notes: [
      { content: "Favorites: Global Windstorm, Relativistic Baseball, Laser Pointer, Hair Dryer, Machine-Gun Jetpack, Neutron Bullet." },
      { blurb?: true, content: "It's been a long time since I gave highest marks to a \"just for fun\" book, but wow, this was fun. So fun that after listening to the audiobook, I immediately proceeded to read the book, for its illustrations. If I'd read this as a kid, I might have been inspired to become a scientist." },
    ],
  )
  @outputs[:all_columns][:"realistic examples: done"] = [insula, cat_mojo, podcast_1, podcast_2, podcast_3, what_if]


  alexander = item_hash(
    author: "Tom Holt",
    title: "Alexander At The World's End",
    variants:    [{ format: :ebook,
                    isbn: "B00GVG00R0",
                    length: 484 }],
    genres: ["historical fiction"],
  )
  emperor = item_hash(
    title: "How to Think Like a Roman Emperor",
    variants:  [{ format: :ebook }],
  )
  born_crime = item_hash(
    author: "Trevor Noah",
    title: "Born a Crime",
    variants:  [{ format: :audiobook,
                  sources: [{ name: "Lexpub" },
                            { name: "Jeffco" }] }],
  )
  nero = item_hash(
    author: "Tom Holt",
    title: "A Song for Nero",
    variants:  [{ format: :ebook }],
    genres: ["historical fiction"],
  )
  true_grit = item_hash(
    title: "True Grit",
    variants:  [{ format: :audiobook,
                  sources: [{ name: "Lexpub" }] }],
    genres: ["historical fiction"],
  )
  lebowski = item_hash(
    title: "Two Gentlemen of Lebowski",
    variants:  [{ format: :audiobook,
                  sources: [{ name: nil,
                              url: "https://www.runleiarun.com/lebowski/" }] }],
    genres: ["historical fiction"],
  )
  how_to = item_hash(
    author: "Randall Munroe",
    title: "How To",
    variants:  [{ format: :print,
                  sources: [{ name: "Lexpub" }] }],
    genres: %w[science weird],
  )
  weird_earth = item_hash(
    title: "Weird Earth",
    variants:  [{ format: :audiobook,
                  sources: [{ name: "Lexpub" },
                            { name: "Hoopla" }] }],
    genres: %w[science weird],
  )
  @outputs[:all_columns][:"realistic examples: planned"] =
    [alexander, emperor, born_crime, nero, true_grit, lebowski, how_to, weird_earth]


  flightless_bird = item_hash(
    rating: 3,
    title: "Flightless Bird",
    genres: ["podcast"],
    variants:
      [{
        format: :audio,
        sources:
          [{
            name: "Spotify",
          },
          {
            url: "https://armchairexpertpod.com/flightless-bird",
          }],
      }],
    experiences:
      [{
        spans:
          [{
            dates: Date.new(2021,10,6)..Date.new(2021,10,11),
            amount: Reading::Item::TimeLength.new(1150),
          },
          {
            dates: Date.new(2021,10,12)..Date.new(2021,12,14),
            amount: Reading::Item::TimeLength.new(3200/7r),
          },
          {
            dates: Date.new(2022,3,1)..,
            amount: Reading::Item::TimeLength.new(21500/7r),
          }],
      }],
  )
  tbfnp = item_hash(
    rating: 4,
    author: "Pete Enns & Jared Byas",
    title: "The Bible for Normal People",
    genres: ["religion", "podcast"],
    variants:
      [{
        format: :audio,
        sources:
          [{
            url: "https://peteenns.com/podcast",
          }],
      }],
    experiences:
      [{
        spans:
          [{
            dates: Date.new(2021,12,1)..Date.new(2021,12,1),
            amount: Reading.time("0:50"),
            name: "#2 Richard Rohr - A Contemplative Look at The Bible",
          },
          {
            dates: Date.new(2021,12,9)..Date.new(2021,12,9),
            amount: Reading.time("1:30"),
            name: "#19 Megan DeFranza - The Bible and Intersex Believers",
          },
          {
            dates: Date.new(2021,12,21)..Date.new(2021,12,21),
            amount: Reading.time("1:30"),
            name: '#160 The Risk of an "Errant" Bible',
            favorite?: true,
          },
          {
            dates: Date.new(2021,12,21)..Date.new(2021,12,21),
            amount: Reading.time("0:50"),
            name: "#164 Where Did Our Bible Come From?",
            favorite?: true,
          },
          {
            dates: Date.new(2022,1,1)..Date.new(2022,1,1),
            amount: Reading.time("0:50"),
            name: "#5 Mike McHargue - Science and the Bible",
          },
          {
            dates: nil,
            amount: Reading.time("0:50"),
            name: "#105 Wil Gafney - Womanist Midrash",
            progress: 0,
          },
        ],
      }],
  )
  escriba_cafe = item_hash(
    rating: 4,
    title: "Escriba Café",
    genres: ["podcast"],
    variants:
      [{
        format: :audio,
        sources:
          [{
            url: "https://www.escribacafe.com",
          }],
      }],
    experiences:
      [{
        spans:
          [{
            dates: Date.new(2021,4,16)..Date.new(2021,4,17),
            amount: Reading.time("0:30"),
            name: "Amor",
          },
          {
            dates: Date.new(2021,4,17)..Date.new(2021,4,18),
            amount: Reading.time("0:30"),
            name: "Diabolus",
          },
          {
            dates: Date.new(2021,4,18)..Date.new(2021,4,19),
            amount: Reading.time("0:30"),
            name: "Máfia",
          },
          {
            dates: Date.new(2021,4,19)..Date.new(2021,4,21),
            amount: Reading.time("0:30"),
            name: "Piratas",
          },
          {
            dates: Date.new(2021,4,21)..Date.new(2021,4,26),
            amount: Reading.time("2:00"),
            name: "Trilogia História do Brasil",
          },
          {
            dates: Date.new(2021,4,26)..Date.new(2021,4,27),
            amount: Reading.time("0:30"),
            name: "Rapa-Nui",
          },
          {
            dates: Date.new(2021,4,27)..Date.new(2021,4,28),
            amount: Reading.time("0:30"),
            name: "Espíritos",
          },
          {
            dates: Date.new(2021,4,28)..Date.new(2021,4,29),
            amount: Reading.time("0:30"),
            name: "Inferno",
          },
          {
            dates: Date.new(2021,4,29)..Date.new(2021,4,30),
            amount: Reading.time("0:30"),
            name: "Pompeia",
          }],
      }],
  )
  born_a_crime = item_hash(
    rating: 4,
    title: "Born a Crime",
    genres: ["memoir"],
    variants:
      [{
        format: :audiobook,
        sources:
          [{
            name: "Lexpub",
          }],
        isbn: "B01DHWACVY",
        length: Reading.time("8:44"),
      }],
    experiences:
      [{
        spans:
          [{
            dates: Date.new(2021,5,1)..Date.new(2021,5,1),
            amount: Reading.time("0:47"),
          },
          {
            dates: Date.new(2021,5,2)..Date.new(2021,5,2),
            amount: Reading.time("0:23"),
          },
          {
            dates: Date.new(2021,5,6)..Date.new(2021,5,15),
            amount: Reading.time("5:00"),
          },
          {
            dates: Date.new(2021,5,20)..Date.new(2021,5,20),
            amount: Reading.time("0:40"),
          },
          {
            dates: Date.new(2021,5,21)..Date.new(2021,5,23),
            amount: Reading.time("1:54"),
          }],
      }],
  )
  @outputs[:all_columns][:"realistic examples: History column"] =
    [flightless_bird, tbfnp, escriba_cafe, born_a_crime]



  @outputs[:config] = {}

  @outputs[:config][:"comment_character"] = []

  a_basic = item_hash(title: "Dracula")
  @outputs[:config][:"column_separator"] = [a_basic]

  @outputs[:config][:"column_separator can be a tab"] = [a_basic]

  @outputs[:config][:"skip_compact_planned"] = []

  a_without_D_a = item_hash(title: "✅rcul")
  @outputs[:config][:"ignored_characters"] = [a_without_D_a]

  a_listening_speed_length = item_hash(
    title: "Dracula",
    variants: [{ format: :audiobook, length: Reading.time("6:00") }],
  )
  @outputs[:config][:"listening speed affects Length"] = [a_listening_speed_length]

  a_listening_speed_history = item_hash(
    title: "Dracula",
    variants: [{ format: :audiobook }],
    experiences: [{ spans: [{
      dates: Date.new(2022,8,1)..Date.new(2022,8,1),
      amount: Reading.time("6:00"),
    }] }],
  )
  @outputs[:config][:"listening speed affects History"] = [a_listening_speed_history]



  # ==== UTILITY METHODS

  def set_config_columns(columns)
    unless columns.empty? || columns.delete(:compact_planned)
      Reading::Config.build(enabled_columns: columns)
    end
  end

  # Removes any blank hashes in arrays, i.e. any that are the same as in the
  # template in config. Data in items must already be complete, i.e. merged with
  # the item template in config.
  def tidy(hash, key)
    hash.fetch(key).map { |item_hash|
      without_blank_hashes(item_hash)
    }
  end

  def without_blank_hashes(item_hash)
    template = Reading::Config.hash.deep_fetch(:item, :template)

    %i[variants experiences notes].each do |attribute|
      item_hash[attribute] =
        item_hash[attribute].reject { |value| value == template[attribute].first }
    end

    # Same for inner hashes arrays at [:variants][:series] and [:variants][:sources].
    item_hash[:variants].each do |variant|
      variant[:series] =
        variant[:series].reject { |value| value == template.deep_fetch(:variants, 0, :series).first }
      variant[:sources] =
        variant[:sources].reject { |value| value == template.deep_fetch(:variants, 0, :sources).first }
    end

    # Same for inner hash array at [:experiences][:spans].
    item_hash[:experiences].each do |variant|
      variant[:spans] =
        variant[:spans].reject { |value| value == template.deep_fetch(:experiences, 0, :spans).first }
    end

    item_hash
  end



  # ==== TESTS

  ## TESTS: ENABLING COLUMNS
  inputs[:enabled_columns].each do |name, file_str|
    columns = name.to_s.split(", ").map(&:to_sym)
    define_method("test_enabled_columns_#{columns.join("_")}") do
      set_config_columns(columns)

      exp = tidy(outputs[:enabled_columns], name)
      act = Reading.parse(lines: file_str, hash_output: true)

      assert_equal exp, act,
        "Failed to parse with these columns enabled: #{name}"

      Reading::Config.build # reset config to default
    end
  end

  ## TESTS: FEATURES OF SINGLE COLUMNS
  inputs.keys.select { |key| key.start_with?("features_") }.each do |group_name|
    inputs[group_name].each do |name, file_str|
      columns_sym = group_name[(group_name.to_s.index("_") + 1)..].to_sym
      columns = columns_sym.to_s.split(", ").map(&:to_sym)
      main_column_humanized = columns.first.to_s.tr("_", " ").capitalize

      if INPUTS_WITH_DEFAULT_TITLE.include?(group_name)
        has_custom_head = file_str.count("|") + 1 > columns.count
        file_str = "#{DEFAULT_TITLE}|#{file_str}" unless has_custom_head
      end

      define_method("test_#{columns_sym}_feature_#{name}") do
        set_config_columns(columns + [:head])

        exp = tidy(outputs[group_name], name)
        act = Reading.parse(lines: file_str, hash_output: true)

        assert_equal exp, act,
          "Failed to parse this #{main_column_humanized} column feature: #{name}"

        Reading::Config.build # reset config to default
      end
    end
  end

  ## TESTS: ALL COLUMNS
  inputs[:all_columns].each do |name, file_str|
    define_method("test_all_columns_#{name}") do
      exp = tidy(outputs[:all_columns], name)
      act = Reading.parse(lines: file_str, hash_output: true)

      assert_equal exp, act,
        "Failed to parse this all-columns example: #{name}"
    end
  end

  ## TESTS: ERRORS
  inputs[:errors].each do |error, inputs_hash|
    inputs_hash.each do |name, file_str|
      define_method("test_error_#{name}") do
        if name.start_with? "OK: " # Should not raise an error.
          refute_nil Reading.parse(lines: file_str, hash_output: true)
        else
          assert_raises error, "Failed to raise #{error} for: #{name}" do
            Reading.parse(lines: file_str, hash_output: true)
          end
        end
      end
    end
  end

  ## TESTS: CUSTOM CONFIG
  inputs[:config].each do |name, (file_str, custom_config)|
    define_method("test_config_#{name}") do
      Reading::Config.build(custom_config)

      exp = tidy(outputs[:config], name)
      act = Reading.parse(lines: file_str, hash_output: true)

      assert_equal exp, act,
        "Failed to parse this config example: #{name}"

      Reading::Config.build # reset config to default
    end
  end
end
