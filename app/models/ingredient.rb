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

  # Parasitic words to remove from ingredient names
  PARASITIC_WORDS = %w[
    large small medium chopped diced sliced fresh peeled minced boneless skinless ground
    lukewarm little warm refrigerated finely thinly roughly and or with breast dough
  ].freeze

  # Canonicalize a string to a normalized root form
  # 1. converts to lowercase
  # 2. replaces non-alphabetic characters with spaces
  # 3. compresses spaces and splits into words
  # 4. removes parasitic words (large, small, chopped, etc.)
  # 5. takes the last remaining word as the root
  # 6. applies simple singularization (removes 'es' or 's' ending)
  def self.canonicalize(string)
    return nil if string.nil?

    # Step 1: Convert to lowercase
    normalized = string.to_s.downcase

    # Step 2: Remove numbers with units, then remaining numbers
    normalized = normalized
                 .gsub(/\d+\.?\d*\s*(#{UNITS_PATTERN_STRING})\b/i, " ")
                 .gsub(/\d+/, " ")

    # Step 2: Replace non-alphabetic characters with spaces
    normalized = normalized.gsub(/[^a-z\s]/, " ")

    # Step 3: Compress spaces and split into words
    words = normalized.gsub(/\s+/, " ").strip.split(" ")

    # Step 4: Remove parasitic words
    words = words.reject { |word| PARASITIC_WORDS.include?(word) }

    # Step 5: Take the last word as root (or empty string if no words left)
    root = words.last || ""

    # Step 6: Apply singularization using ActiveSupport::Inflector
    singularize(root)
  end

  # Singularize a word using ActiveSupport::Inflector with special cases
  # Returns the word as-is if empty or very short (1-2 chars)
  def self.singularize(word)
    return word if word.empty?
    return word if word.length <= 2

    # Special cases where ActiveSupport::Inflector produces incorrect results
    special_cases = {
      "pasta" => "pasta"      # Inflector incorrectly singularizes "pasta" to "pastum"
    }

    return special_cases[word] if special_cases.key?(word)

    # Use ActiveSupport::Inflector for proper singularization
    result = ActiveSupport::Inflector.singularize(word)

    # Fix any incorrect results from Inflector
    special_cases[result] || result
  end
end
