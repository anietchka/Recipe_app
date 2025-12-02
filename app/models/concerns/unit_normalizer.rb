module UnitNormalizer
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
    "pcs" => "pcs",
    "pounds" => "lb",
    "pound" => "lb",
    "lb" => "lb",
    "ounces" => "oz",
    "ounce" => "oz",
    "oz" => "oz"
  }.freeze

  # Module method: Normalizes a unit string directly via the concern
  # Uses Ingredient::MEASUREMENT_UNITS as the reference
  # - converts plural forms to singular (cups -> cup, tablespoons -> tbsp)
  # - converts full names to abbreviations (teaspoon -> tsp, tablespoon -> tbsp)
  # - returns nil if unit is not recognized
  # - returns unit as-is if already normalized
  def self.normalize_unit(unit)
    return nil if unit.nil? || unit.blank?

    normalized = unit.to_s.downcase.strip

    # Check if unit is already in MEASUREMENT_UNITS
    return normalized if Ingredient::MEASUREMENT_UNITS.include?(normalized)

    # Try to map it
    mapped = UNIT_MAPPING[normalized]
    return mapped if mapped && Ingredient::MEASUREMENT_UNITS.include?(mapped)

    # If not found, return nil
    nil
  end
end
