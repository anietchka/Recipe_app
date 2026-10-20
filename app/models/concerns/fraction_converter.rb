module FractionConverter
  extend ActiveSupport::Concern

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
end
