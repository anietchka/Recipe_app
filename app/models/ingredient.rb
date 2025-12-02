class Ingredient < ApplicationRecord
  # Common measurement units used in recipes
  MEASUREMENT_UNITS = %w[
    g kg mg ml l cl dl oz lb
    cup tbsp tsp pcs
  ].freeze

  # Pre-compiled regex pattern string for measurement units to avoid ReDoS warnings
  # This pattern is used in both canonicalize and recipe import parsing
  UNITS_PATTERN_STRING = MEASUREMENT_UNITS.join("|").freeze

  has_many :recipe_ingredients, dependent: :destroy
  has_many :recipes, through: :recipe_ingredients
  has_many :pantry_items, dependent: :destroy

  validates :canonical_name, presence: true, uniqueness: true

  # Autocomplete search for ingredients with smart filtering and ordering
  # Filters out overly complex names and prioritizes simple, relevant results
  #
  # @param term [String] Search term
  # @param limit [Integer] Maximum number of results (default: 15)
  # @return [ActiveRecord::Relation] Ingredients matching the search
  def self.autocomplete(term, limit: 15)
    return none if term.blank?

    normalized_term = term.strip.downcase
    return none if normalized_term.blank?

    # Sanitize the term for SQL LIKE patterns (escape special characters)
    sanitized_term = ActiveRecord::Base.connection.quote_string(normalized_term)

    # Build the subquery with filtering and calculated columns
    subquery = where(
      "LOWER(name) LIKE ? OR LOWER(canonical_name) LIKE ?",
      "%#{sanitized_term}%",
      "%#{sanitized_term}%"
    )
    .where("LENGTH(name) <= ?", 40)
    .where("LOWER(name) NOT LIKE ?", "%such as to %")
    .where("name NOT LIKE ?", "%(%")
    .select(
      "ingredients.*",
      Arel.sql("CASE
        WHEN LOWER(name) LIKE '#{sanitized_term}%' OR LOWER(canonical_name) LIKE '#{sanitized_term}%'
        THEN 1
        ELSE 2
      END AS relevance_rank"),
      Arel.sql("LENGTH(name) AS name_length")
    )

    # Use from with subquery to make calculated columns available for ordering
    from("(#{subquery.to_sql}) AS ingredients")
      .order(Arel.sql("relevance_rank ASC, name_length ASC, name ASC"))
      .limit(limit)
  end

  # Canonicalize a string to a normalized form
  # - converts to lowercase
  # - removes numbers and common measurement units (g, kg, ml, l, etc.)
  # - removes non-alphabetic characters (replaces with space)
  # - compresses spaces
  # - trims whitespace
  def self.canonicalize(string)
    return nil if string.nil?

    string.to_s
          .downcase
          .gsub(/\d+\.?\d*\s*(#{UNITS_PATTERN_STRING})\b/i, " ") # Remove numbers with units
          .gsub(/\d+/, " ")           # Remove remaining numbers
          .gsub(/[^a-z\s]/, " ")      # Replace non-alphabetic characters with space
          .gsub(/\s+/, " ")           # Compress multiple spaces to single space
          .strip                      # Trim whitespace
  end
end
