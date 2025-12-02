module FractionConverter
  extend ActiveSupport::Concern

  # Common fractions map for conversion
  COMMON_FRACTIONS = {
    0.5 => "1/2",
    0.333 => "1/3",
    0.667 => "2/3",
    0.25 => "1/4",
    0.75 => "3/4",
    0.125 => "1/8",
    0.375 => "3/8",
    0.625 => "5/8",
    0.875 => "7/8"
  }.freeze

  # Unicode fraction to text fraction mapping
  UNICODE_FRACTION_MAP = {
    "½" => " 1/2",
    "⅓" => " 1/3",
    "⅔" => " 2/3",
    "¼" => " 1/4",
    "¾" => " 3/4",
    "⅛" => " 1/8",
    "⅜" => " 3/8",
    "⅝" => " 5/8",
    "⅞" => " 7/8"
  }.freeze

  # Module method: Normalizes Unicode fractions in text to text fractions
  # Converts Unicode fractions (½, ⅓, etc.) to text fractions (" 1/2", " 1/3", etc.)
  # Adds space before fraction to separate it from preceding content
  def self.normalize_fractions(text)
    return text if text.nil?

    normalized = text.dup
    UNICODE_FRACTION_MAP.each do |unicode, replacement|
      normalized.gsub!(unicode, replacement)
    end

    normalized
  end

  # Converts a decimal (0.0 to 1.0) to a common fraction string
  # Returns nil if no common fraction matches
  def convert_decimal_to_fraction(decimal)
    COMMON_FRACTIONS.each do |target_decimal, fraction|
      if (decimal - target_decimal).abs < 0.01
        return fraction
      end
    end

    nil
  end
end
