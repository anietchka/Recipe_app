class Ingredient < ApplicationRecord
  # Common measurement units used in recipes
  MEASUREMENT_UNITS = %w[
    g kg mg ml l cl dl oz lb
    cup cups tbsp tsp
    teaspoon teaspoons tablespoon tablespoons
    piece pieces pcs
  ].freeze

  has_many :recipe_ingredients, dependent: :destroy
  has_many :recipes, through: :recipe_ingredients
  has_many :pantry_items, dependent: :destroy

  validates :canonical_name, presence: true, uniqueness: true

  # Canonicalize a string to a normalized form
  # - converts to lowercase
  # - removes numbers and common measurement units (g, kg, ml, l, etc.)
  # - removes non-alphabetic characters (replaces with space)
  # - compresses spaces
  # - trims whitespace
  def self.canonicalize(string)
    return nil if string.nil?

    units_pattern = MEASUREMENT_UNITS.join("|")
    string.to_s
          .downcase
          .gsub(/\d+\.?\d*\s*(#{units_pattern})\b/i, " ") # Remove numbers with units
          .gsub(/\d+/, " ")           # Remove remaining numbers
          .gsub(/[^a-z\s]/, " ")      # Replace non-alphabetic characters with space
          .gsub(/\s+/, " ")           # Compress multiple spaces to single space
          .strip                      # Trim whitespace
  end
end
