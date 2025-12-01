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
