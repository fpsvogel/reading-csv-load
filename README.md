<h1 align="center">Reading</h1>

Reading is a Ruby gem that parses a CSV reading log. [My personal site's Reading page](https://fpsvogel.com/reading/) and [a reading statistics CLI app](https://github.com/fpsvogel/readstat) are built with the help of this gem.

### Table of Contents

- [Why am I building this?](#why-am-i-building-this)
- [Installation](#installation)
- [Docs](#docs)
- [Usage](#usage)
  - [Try out a CSV string](#try-out-a-csv-string)
  - [Real usage](#real-usage)
  - [Custom config](#custom-config)
- [How to add a reading page to your site](#how-to-add-a-reading-page-to-your-site)
- [Contributing](#contributing)
- [License](#license)

## Why am I building this?

Because I love reading and keeping track of my reading, but I don't like the limitations of Goodreads and similar sites. In particular:

- I don't like going into a site or app every time I want to make a small change such as adding a note. I find it much faster to edit a plain text file which I always have open on my computer, or which I can quickly pull up on my phone via a Dropbox-syncing text editor (I use the Android app [Simple Text](https://play.google.com/store/apps/details?id=simple.text.dropbox)).
- I don't like being limited to a database of existing book metadata. In Goodreads you can add new titles to their database, but it's cumbersome. Plus, it's nice to be able to track items other than books, such as podcasts.
- On Goodreads, my reading data is theirs, not mine.

So I started tracking my reading and notes directly in a CSV file. Then a problem arose: how to share my reading log with friends? I'm sure they wouldn't want to wade through my massive CSV file.

That's where Reading helps: it transforms my `reading.csv` into data that I can selectively display on a page on my site.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'reading'
```

And then execute:

```
$ bundle install
```

Or install it yourself as:

```
$ gem install reading
```

## Docs

[CSV Format Guide](https://github.com/fpsvogel/reading/blob/main/doc/csv-format.md) on how to set up your own CSV reading log.

[Parsed Output Guide](https://github.com/fpsvogel/reading/blob/main/doc/parsed-output.md) on the structure into which the Reading gem parses the CSV rows.

[`test/csv_parse_test.rb`](https://github.com/fpsvogel/reading/blob/main/test/csv_parse_test.rb) also documents the CSV features via examples.

## Usage

### Try out a CSV string

To quickly see the output from a CSV string, use the `reading` command:

```
$ reading '3|📕Trying|Little Library 1970147288'
```

The pipe character (`|`) is the column separator. The above example includes the first three columns (Rating, Head, and Sources) which contain a rating, format (book), title, source, and ISBN. You'll see all those reflected in the parsed data that is output to the console after you run the command.

An optional second argument specifies enabled columns. To omit the Rating column from the example above:

```
$ reading '📕Trying|Little Library 1970147288' 'head, sources'
```

### Real usage

The most basic usage of the gem is simply to specify the path to your CSV reading log, and it will be parsed with the default configuration.

```ruby
require "reading/csv"

file_path = "/home/user/reading.csv"
csv = Reading::CSV.new(path: file_path)
items = csv.parse
```

This returns an array of Structs, each representing an item (such as a book or podcast) structured like the template hash in `default_config[:item][:template]` in [config.rb](https://github.com/fpsvogel/reading/blob/main/lib/reading/config.rb).

If instead of a file path you want to directly parse a string or a file (or anything else responding to `#each_line`):

```ruby
require "reading/csv"

csv_string_or_file = File.read(file_path)
csv = Reading::CSV.new(csv_string_or_file)
items = csv.parse
```

### Custom config

To use custom configuration, pass a config hash when initializing.

Here's an example. If you don't want to use all the columns (as in [the minimal example in the CSV format guide](https://github.com/fpsvogel/reading/blob/main/doc/csv-format.md#a-minimal-reading-log)), you'll need to initialize a `Reading::CSV` with a config including only the desired columns, like this:

```ruby
require "reading/csv"

custom_config = {
  csv: {
    enabled_columns: [:head, :dates_finished]
  }
}
file_path = "/home/user/reading.csv"
csv = Reading::CSV.new(path: file_path, config: custom_config)
items = csv.parse
```

## How to add a reading page to your site

After Reading parses your CSV reading log, it's up to you to display that parsed information on a webpage. I've set up my personal site so that it automatically parses my reading log during site generation, and it's even automatically generated every week. That means my site's Reading page automatically syncs to my reading log on a weekly basis.

I explain how I did this in my tutorial ["Build a blog with Bridgetown"](https://fpsvogel.com/posts/2021/build-a-blog-with-bridgetown), which may give you ideas even if you don't use [Bridgetown](https://www.bridgetownrb.com/) to build your site… but you should use Bridgetown, it's great 😉

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fpsvogel/reading.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
