<h1 align="center">Reading</h1>

Reading is a Ruby gem that parses a CSV reading log. [My personal site's Reading page](https://fpsvogel.com/reading/) is built with the help of this gem.

### Table of Contents

- [Why?](#why)
- [Installation](#installation)
- [Docs](#docs)
- [Usage](#usage)
  - [Try out a CSV file or string](#try-out-a-csv-file-or-string)
  - [Parse in Ruby](#parse-in-ruby)
  - [Parse with custom config](#parse-with-custom-config)
  - [Filtering the output](#filtering-the-output)
- [How to add a reading page to your site](#how-to-add-a-reading-page-to-your-site)
- [Contributing](#contributing)
- [License](#license)

## Why?

Because I love reading, and keeping a plain-text reading log helps me remember, reflect on, and plan my reading (and listening, and watching).

My CSV reading log serves the same role as Goodreads used to, but it lets me do a few things that Goodreads doesn't:

- Add items of any format: podcasts, documentaries, etc.
- Own my data.
- Edit and search in a plain text file, which is faster than navigating a site or app. I can even pull up my reading log on my phone via a Dropbox-syncing text editor app—[Simple Text](https://play.google.com/store/apps/details?id=simple.text.dropbox) is the one I use.
- Get the features I need by adding them myself, instead of wishing and waiting for the perfect Goodreads-esque service. For example, when I started listening to more podcasts, I added automatic progress tracking based on episode length and frequency, so that I didn't have to count episodes and sum up hours.

So a CSV reading log is great, but there's one problem: how to share it with friends? No one wants to wade through a massive CSV file.

That's where this gem helps: it transforms my `reading.csv` into data that I can selectively display on a page on my site.

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

[Parsed Output Guide](https://github.com/fpsvogel/reading/blob/main/doc/parsed-output.md) on the structure into which the Reading gem parses CSV rows.

[`test/parse_test.rb`](https://github.com/fpsvogel/reading/blob/main/test/parse_test.rb) has more examples of the CSV format.

## Usage

### Try out a CSV file or string

To quickly see the parsed output from a CSV file, use the `parsereading` command:

```
$ parsereading /home/felipe/reading.csv
```

The same command can be used with a CSV string argument:

```
$ parsereading '3|📕Trying|Little Library 1970147288'
```

See the [CSV Format Guide](https://github.com/fpsvogel/reading/blob/main/doc/csv-format.md) for more on columns, but here suffice it to note that this CSV string has the first three columns (Rating, Head, and Sources).

An optional second argument specifies enabled columns. The CSV string above already omits several right-side columns, but to omit a left-side or middle column we'll have to disable it. For example, to omit the Rating column from the example above:

```
$ reading '📕Trying|Little Library 1970147288' 'head, sources'
```

### Parse in Ruby

To parse a CSV reading log in Ruby rather than on the command line:

```ruby
require "reading"

file_path = "/home/user/reading.csv"
items = Reading.parse(file_path)
```

This returns an array of [Items](https://github.com/fpsvogel/reading/blob/main/lib/reading/item.rb), which are essentially a wrapper with the same structure as the template Hash in `Config#default_config[:item][:template]` in [config.rb](https://github.com/fpsvogel/reading/blob/main/lib/reading/config.rb), but providing a few conveniences such as dot access (`item.notes` instead of `item[:notes]`).

If instead of a file path you want to directly parse a String (or anything else responding to `#each_line`, such as a `File`):

```ruby
require "reading"

string = File.read(file_path)
items = Reading.parse(lines: string)
```

### Parse with custom config

To use custom configuration, pass a config Hash when initializing.

Here's an example. If you don't want to use all the columns (as in [the minimal example in the CSV format guide](https://github.com/fpsvogel/reading/blob/main/doc/csv-format.md#a-minimal-reading-log)), you'll need to pass in a config including only the desired columns, like this:

```ruby
require "reading"

custom_config = { enabled_columns: [:head, :end_dates] }
file_path = "/home/user/reading.csv"
items = Reading.parse(file_path, config: custom_config)
```

### Filtering the output

Once you've parsed your reading log, you can easily filter the output like this:

```ruby
# (Parse a reading log into `items` as above)
# ...
filtered_items = Reading.filter(
  items: items,
  minimum_rating: 4,
  status: [:done, :in_progress],
  excluded_genres: ["cats", "memoir"],
)
```

## How to add a reading page to your site

After Reading parses your CSV reading log, it's up to you to display that parsed information on a web page. I've set up my personal site so that it parses my reading log during site generation, and it's even automatically generated every week. That means my site's "Reading" page automatically syncs to my reading log on a weekly basis.

I explain how I did this in my tutorial ["Build a blog with Bridgetown"](https://fpsvogel.com/posts/2021/build-a-blog-with-bridgetown), which may give you ideas even if you don't use [Bridgetown](https://www.bridgetownrb.com/) to build your site… but you should use Bridgetown, it's great 😉

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/fpsvogel/reading.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
