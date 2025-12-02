module UnitNormalizer
  extend ActiveSupport::Concern

  # Mapping of common unit variations to normalized forms
  UNIT_MAPPING = {
    "cups" => "cup",
    "cup" => "cup",
    "tablespoons" => "tbsp",
    "tablespoon" => "tbsp",
    "tbsp" => "tbsp",
    "teaspoons" => "tsp",
    "teaspoon" => "tsp",
    "tsp" => "tsp",
    "pieces" => "pcs",
    "piece" => "pcs",
    "pcs" => "pcs"
  }.freeze

  class_methods do
    # Normalizes a unit string to one of the standard MEASUREMENT_UNITS
    # - converts plural forms to singular (cups -> cup, tablespoons -> tbsp)
    # - converts full names to abbreviations (teaspoon -> tsp, tablespoon -> tbsp)
    # - returns nil if unit is not recognized
    # - returns unit as-is if already normalized
    # Requires MEASUREMENT_UNITS constant to be defined in the including class
    def normalize_unit(unit)
      return nil if unit.nil? || unit.blank?

      normalized = unit.to_s.downcase.strip

      # Check if unit is already in MEASUREMENT_UNITS
      return normalized if measurement_units.include?(normalized)

      # Try to map it
      mapped = UNIT_MAPPING[normalized]
      return mapped if mapped && measurement_units.include?(mapped)

      # If not found, return nil
      nil
    end

    private

    def measurement_units
      const_get(:MEASUREMENT_UNITS)
    end
  end
end
