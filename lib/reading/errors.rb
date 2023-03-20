module Reading
  class Error < StandardError; end

  # Means there was a problem accessing a file.
  class FileError < Reading::Error; end

  # Means unexpected input was encountered during parsing.
  class ParsingError < Reading::Error; end

  # Means something in the Head column (author, title, etc.) is invalid.
  class InvalidHeadError < Reading::Error; end

  # Means there are too many columns in a row.
  class TooManyColumnsError < Reading::Error; end

  # class MissingHeadError < Reading::Error; end

  # Means a date is unparsable, or a set of dates does not make logical sense.
  class InvalidDateError < Reading::Error; end
end
