module Recipes
  class ImportFromJson
    include FractionConverter
    def self.call(file_path = nil)
      new(file_path).call
    end

    def initialize(file_path = nil)
      @file_path = file_path || default_file_path
    end

    def call
      recipes_data = load_json_file
      recipes_data.each do |recipe_data|
        import_recipe(recipe_data)
      end
    end

    private

    attr_reader :file_path

    def default_file_path
      Rails.root.join("db", "data", "recipes-en.json")
    end

    def load_json_file
      file_content = File.read(file_path)
      JSON.parse(file_content)
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse JSON file: #{e.message}"
      raise
    rescue Errno::ENOENT => e
      Rails.logger.error "File not found: #{file_path}"
      raise
    end

    def import_recipe(recipe_data)
      recipe = Recipe.create!(
        title: recipe_data["title"],
        description: recipe_data["description"],
        instructions: recipe_data["instructions"],
        total_time_minutes: recipe_data["total_time_minutes"],
        image_url: recipe_data["image_url"],
        source_url: recipe_data["source_url"],
        rating: recipe_data["rating"],
        ratings_count: recipe_data["ratings_count"]
      )

      import_ingredients(recipe, recipe_data["ingredients"] || [])
    end

    def import_ingredients(recipe, ingredients_list)
      ingredients_list.each do |ingredient_text|
        import_ingredient(recipe, ingredient_text)
      end
    end

    def import_ingredient(recipe, ingredient_text)
      parsed = parse_ingredient(ingredient_text)
      ingredient_name = parsed[:name]
      quantity = parsed[:quantity]
      fraction = parsed[:fraction]
      unit = parsed[:unit]
      precision = parsed[:precision]

      canonical_name = Ingredient.canonicalize(ingredient_name)
      return if canonical_name.blank?

      ingredient = Ingredient.find_or_create_by!(canonical_name: canonical_name) do |ing|
        ing.name = ingredient_name
      end

      # Update ingredient name if it was changed (e.g., if it previously had quantity/unit in name)
      ingredient.update(name: ingredient_name) if ingredient.name != ingredient_name

      RecipeIngredient.create!(
        recipe: recipe,
        ingredient: ingredient,
        original_text: ingredient_text,
        quantity: quantity,
        fraction: fraction,
        unit: unit,
        precision: precision
      )
    end

    # Parses ingredient text and extracts quantity, fraction, unit, name, and precision in a single pass
    # Returns a hash with :quantity, :fraction, :unit, :name, and :precision
    # Precision is everything after the first comma in the ingredient name
    def parse_ingredient(ingredient_text)
      normalized = FractionConverter.normalize_fractions(ingredient_text.dup)
      text = normalized.strip

      # First, try to match quantities in parentheses (e.g., "3 (12 ounce) packages")
      parenthetical_match = match_parenthetical_pattern(text)
      if parenthetical_match
        return parse_parenthetical_match(parenthetical_match, text, ingredient_text)
      end

      match = match_ingredient_pattern(text)
      return build_empty_parsed_result(ingredient_text) unless match

      whole_number_text, fraction_text, unit = extract_matched_parts(match)

      # Handle edge case: Unicode fractions that normalize incorrectly
      whole_number_text, fraction_text, unit = handle_fraction_edge_case(
        text, whole_number_text, fraction_text, unit
      )

      quantity, fraction_text = calculate_quantity_and_fraction(whole_number_text, fraction_text)
      ingredient_name, precision = extract_ingredient_name_and_precision(text, match, ingredient_text)

      {
        quantity: quantity,
        fraction: fraction_text,
        unit: unit,
        name: ingredient_name,
        precision: precision
      }
    end

    def match_parenthetical_pattern(text)
      units_pattern = build_units_pattern
      # Match patterns like "3 (12 ounce)", "1 (12 fluid ounce)", or "(.25 ounce)"
      # Captures: outer quantity, inner quantity, unit
      # Note: \d*\.?\d+ allows numbers starting with a dot (e.g., ".25")
      regex = /^(\d*\.?\d+)?\s*\((\d*\.?\d+)\s*(#{units_pattern})\)/i
      text.match(regex)
    end

    def parse_parenthetical_match(match, text, ingredient_text)
      inner_quantity_text = match[2]
      unit_text = match[3]

      # Use the inner quantity and unit from parentheses
      # Ignore the outer quantity (e.g., "3" in "3 (12 ounce)") as it's just a count of items
      # Convert decimal to quantity and fraction if possible
      quantity, fraction = calculate_quantity_and_fraction(inner_quantity_text, nil)
      unit = UnitNormalizer.normalize_unit(unit_text&.downcase)

      # Extract ingredient name: everything after the closing parenthesis
      match_end = match.end(0)
      ingredient_name_with_precision = text[match_end..-1]&.strip
      ingredient_name_with_precision = ingredient_name_with_precision.presence || ingredient_text.strip

      # Split name and precision (everything after first comma goes to precision)
      name, precision = split_name_and_precision(ingredient_name_with_precision)

      {
        quantity: quantity,
        fraction: fraction,
        unit: unit,
        name: name,
        precision: precision
      }
    end

    def match_ingredient_pattern(text)
      units_pattern = build_units_pattern
      # Match: optional whole number, optional fraction, optional unit
      # Use negative lookahead to prevent capturing a number that's part of a fraction
      # Pattern: (whole_number not followed by /) followed by optional fraction, then optional unit
      # Note: \d*\.?\d+ allows numbers starting with a dot (e.g., ".25")
      regex = /^(\d*\.?\d+(?!\/))?\s*(\d+\/\d+)?\s*(#{units_pattern})?/i
      text.match(regex)
    end

    def build_units_pattern
      # Build pattern from MEASUREMENT_UNITS and common variations
      base_units = Ingredient::UNITS_PATTERN_STRING
      variations = %w[
        cups tablespoons teaspoons pieces
        tablespoon teaspoon piece
        pounds pound ounces ounce
        fluid\s+ounces fluid\s+ounce fl\s+oz
      ].join("|")
      "(?:#{base_units}|#{variations})"
    end

    def extract_matched_parts(match)
      whole_number_text = match[1]&.strip.presence
      fraction_text = match[2]
      unit = match[3]&.downcase
      normalized_unit = UnitNormalizer.normalize_unit(unit) if unit
      [ whole_number_text, fraction_text, normalized_unit ]
    end

    def convert_decimal_to_fraction(decimal)
      whole = decimal.to_i
      decimal_part = decimal - whole

      fraction = super(decimal_part)
      return { whole: whole, fraction: fraction } if fraction

      # If no common fraction matches, return nil to keep as decimal
      nil
    end

    def calculate_quantity(whole_number_text, fraction_text)
      whole_number = whole_number_text&.to_f || 0
      return nil if whole_number.zero? && fraction_text.nil?

      whole_number.zero? ? nil : whole_number
    end

    def build_empty_parsed_result(ingredient_text)
      name, precision = split_name_and_precision(ingredient_text.strip)
      {
        quantity: nil,
        fraction: nil,
        unit: nil,
        name: name,
        precision: precision
      }
    end

    def handle_fraction_edge_case(text, whole_number_text, fraction_text, unit)
      # Handle the case where we have a whole number but no fraction, but there might be a fraction
      # This happens with Unicode fractions like "½ cup" which normalize to " 1/2 cup"
      # The regex might match "1" as whole_number_text instead of "1/2" as fraction_text
      return [ whole_number_text, fraction_text, unit ] unless whole_number_text.present? && fraction_text.nil?

      # Check if the whole_number_text is actually the numerator of a fraction like "1/2"
      fraction_pattern = /^#{Regexp.escape(whole_number_text)}\/(\d+)/
      return [ whole_number_text, fraction_text, unit ] unless text.match(fraction_pattern)

      # The whole_number_text is actually part of a fraction
      fraction_match = text.match(/^(\d+\/\d+)/)
      return [ whole_number_text, fraction_text, unit ] unless fraction_match

      # Extract unit after the fraction
      after_fraction = text[fraction_match.end(0)..-1]
      unit = extract_unit_from_text(after_fraction)

      [ nil, fraction_match[1], unit ]
    end

    def extract_unit_from_text(text)
      return nil if text.blank?

      units_pattern = build_units_pattern
      unit_match = text.strip.match(/^(#{units_pattern})/i)
      return nil unless unit_match

      UnitNormalizer.normalize_unit(unit_match[1]&.downcase)
    end

    def calculate_quantity_and_fraction(whole_number_text, fraction_text)
      # If we have a decimal, try to convert it to fraction
      if whole_number_text&.include?(".")
        handle_decimal_quantity(whole_number_text, fraction_text)
      else
        quantity = calculate_quantity(whole_number_text, fraction_text)
        [ quantity, fraction_text ]
      end
    end

    def handle_decimal_quantity(whole_number_text, fraction_text)
      decimal = whole_number_text.to_f
      converted = convert_decimal_to_fraction(decimal)

      # If conversion failed, use decimal as quantity
      return [ decimal, fraction_text ] if converted.nil?

      # Convert the whole part and fraction part separately
      whole_part = converted[:whole]
      new_fraction_text = converted[:fraction]
      # If whole_part is 0 and we have a fraction, quantity should be nil
      quantity = whole_part.zero? ? nil : whole_part.to_f
      [ quantity, new_fraction_text ]
    end

    def extract_ingredient_name_and_precision(text, match, ingredient_text)
      match_end = match.end(0)

      # Check if there's a trailing 's' after the matched unit (e.g., "cups" vs "cup")
      match_end = adjust_match_end_for_plural(text, match, match_end)

      # Extract everything after the match (and optional 's')
      ingredient_name_with_precision = text[match_end..-1]&.strip

      # If we got an empty string or nil, use the original text
      ingredient_name_with_precision = ingredient_name_with_precision.presence || ingredient_text.strip

      # Split name and precision (everything after first comma goes to precision)
      split_name_and_precision(ingredient_name_with_precision)
    end

    # Splits ingredient name and precision based on first comma
    # Returns [name, precision] where precision is everything after the first comma
    def split_name_and_precision(text)
      return [ text, nil ] if text.blank?

      parts = text.split(",", 2)
      name = parts[0]&.strip
      precision = parts[1]&.strip.presence

      [ name, precision ]
    end

    def adjust_match_end_for_plural(text, match, match_end)
      return match_end unless match[3].present? && match_end < text.length
      return match_end unless text[match_end] == "s"

      match_end + 1
    end
  end
end
