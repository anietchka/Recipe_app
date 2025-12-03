module Recipes
  class ImportFromJson
    include FractionConverter
    include UnitNormalizer

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

    # Default JSON file location used in production import
    def default_file_path
      Rails.root.join("db", "data", "recipes-en.json")
    end

    def load_json_file
      unless File.exist?(@file_path)
        error_msg = "File not found: #{@file_path}. Run 'rails recipes:download' to download it from S3."
        Rails.logger.error error_msg
        raise Errno::ENOENT, error_msg
      end

      file_content = File.read(@file_path)
      JSON.parse(file_content)
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse JSON file: #{e.message}"
      raise
    end

    # Recipe import
    def import_recipe(recipe_data)
      recipe = Recipe.create!(
        title:      recipe_data["title"],
        cook_time:  recipe_data["cook_time"],
        prep_time:  recipe_data["prep_time"],
        image_url:  recipe_data["image_url"] || recipe_data["image"],
        category:   recipe_data["category"],
        ratings:    recipe_data["ratings"]
      )

      import_ingredients(recipe, recipe_data["ingredients"] || [])
    end

    def import_ingredients(recipe, ingredients_list)
      ingredients_list.each do |ingredient_text|
        import_ingredient(recipe, ingredient_text)
      end
    end

    # Single ingredient line import
    def import_ingredient(recipe, ingredient_text)
      parsed = parse_ingredient(ingredient_text)

      canonical_name = Ingredient.canonicalize(parsed[:name])
      return if canonical_name.blank?

      ingredient = Ingredient.find_or_initialize_by(canonical_name: canonical_name)
      ingredient.name = canonical_name.titleize
      ingredient.save!

      quantity = parsed[:quantity]
      fraction = parsed[:fraction]
      unit     = parsed[:unit]

      # When a quantity is present but no unit is specified, we assume a piece count ("pcs").
      unit = "pcs" if quantity.present? && unit.nil?

      RecipeIngredient.create!(
        recipe:        recipe,
        ingredient:    ingredient,
        original_text: ingredient_text,
        quantity:      quantity,
        fraction:      fraction,
        unit:          unit
      )
    end

    # Parsing helpers
    def parse_ingredient(ingredient_text)
      text = ingredient_text.to_s.strip
      text = FractionConverter.normalize_fractions(text).squish

      # 1. Handle parenthetical patterns first (e.g. "(.25 ounce)", "3 (12 ounce) ...")
      parenthetical_result = parse_parenthetical(text, ingredient_text)
      return parenthetical_result if parenthetical_result.present?

      # 2. Fallback to standard "quantity + unit + name" parsing
      quantity, fraction, unit, name = parse_standard_quantity_unit(text, ingredient_text)

      {
        quantity: quantity,
        fraction: fraction,
        unit:     unit,
        name:     name
      }
    end

    # Parenthetical patterns
    #
    # Examples:
    # - "(.25 ounce) package active dry yeast"
    # - "3 (12 ounce) packages refrigerated biscuit dough"
    # - "(12 ounce) packages refrigerated biscuit dough"
    # - "2 (1 pound) packages ground beef"

    def parse_parenthetical(text, ingredient_text)
      # Look for the first "(...)" block
      match = text.match(/\(([^)]+)\)/)
      return nil unless match

      inner = match[1].strip
      inner_tokens = inner.split

      # Extract numeric value from inside the parenthesis
      number_token = inner_tokens.find { |t| t.match?(/\A\d*\.?\d+\z/) }
      return nil unless number_token

      # Normalize values starting with ".", e.g. ".25" -> "0.25"
      number_token = "0#{number_token}" if number_token.start_with?(".")

      # Extract unit from inner tokens using UnitNormalizer
      unit_token = inner_tokens.find { |t| UnitNormalizer.normalize_unit(t).present? }
      unit = UnitNormalizer.normalize_unit(unit_token) if unit_token

      quantity, fraction = calculate_quantity_and_fraction(number_token, nil)

      # Everything after the closing parenthesis is considered the ingredient name
      name_part = text[match.end(0)..].to_s.strip
      # Remove everything after the first comma (precision part)
      name_part = name_part.split(",").first&.strip if name_part.present?
      name_part = ingredient_text.split(",").first&.strip if name_part.blank?

      {
        quantity: quantity,
        fraction: fraction,
        unit:     unit,
        name:     name_part
      }
    end

    # Standard patterns
    #
    # Examples:
    # - "1 cup warm milk"
    # - "½ cup lukewarm water"
    # - "⅓ teaspoon salt"
    # - "1 ½ cups all-purpose flour, sifted"
    # - "2 ⅔ tablespoons oil, sifted"
    # - "8 ounce cheese"
    # - "12 ounces flour"
    # - "200g pasta, finely chopped"
    # - "2 eggs, only yellow, beaten"
    # - "1L milk"
    # - "2l water"
    # - "ground beef"

    def parse_standard_quantity_unit(text, ingredient_text)
      tokens = text.split
      return [ nil, nil, nil, ingredient_text ] if tokens.empty?

      quantity = nil
      fraction = nil
      unit     = nil
      name_start_index = 0

      first_token = tokens[0]

      # Case 1: attached number + unit (e.g. "200g", "1L", "2l")
      if first_token =~ /\A(\d+(?:\.\d+)?)([A-Za-z]+)\z/
        number_str = Regexp.last_match(1)
        unit_str   = Regexp.last_match(2)

        quantity, fraction = calculate_quantity_and_fraction(number_str, nil)
        unit = UnitNormalizer.normalize_unit(unit_str)

        name_start_index = 1
      else
        # Case 2: separated quantity / fraction / unit
        whole_number_text = nil
        fraction_text     = nil

        # Potential whole number or decimal (e.g. "1", "2", "1.5")
        if first_token.match?(/\A\d+(?:\.\d+)?\z/)
          whole_number_text = first_token
          name_start_index  = 1

          # Optional fraction right after whole number (e.g. "1 1/2")
          if tokens[1] && tokens[1].match?(/\A\d+\/\d+\z/)
            fraction_text    = tokens[1]
            name_start_index = 2
          end
        # Case: fraction only at the beginning (e.g. "1/2 cup ...", after unicode normalization)
        elsif first_token.match?(/\A\d+\/\d+\z/)
          fraction_text     = first_token
          name_start_index  = 1
        end

        quantity, fraction = calculate_quantity_and_fraction(whole_number_text, fraction_text)

        # Try to detect a unit token right after quantity/fraction
        if tokens[name_start_index]
          unit_candidate = tokens[name_start_index].gsub(/[^[:alpha:]]/, "")
          normalized_unit = UnitNormalizer.normalize_unit(unit_candidate)
          if normalized_unit
            unit = normalized_unit
            name_start_index += 1
          end
        end
      end

      name_tokens = tokens[name_start_index..] || []
      name = name_tokens.join(" ").strip
      # Remove everything after the first comma (precision part)
      name = name.split(",").first&.strip if name.present?
      name = ingredient_text.split(",").first&.strip if name.blank?

      [ quantity, fraction, unit, name ]
    end

    # Fraction utilities

    # Given an optional whole number and an optional fraction string,
    # return a numeric quantity and a canonical fraction for display.
    #
    # Examples:
    # - whole="1", fraction=nil      -> quantity=1.0, fraction=nil
    # - whole=nil, fraction="1/2"    -> quantity=nil, fraction="1/2"
    # - whole="1", fraction="1/2"    -> quantity=1.0, fraction="1/2"
    # - whole="1.5", fraction=nil    -> quantity=1.0, fraction="1/2"
    # - whole="0.25", fraction=nil   -> quantity=nil, fraction="1/4"
    def calculate_quantity_and_fraction(whole_number_text, fraction_text)
      whole_number_text = whole_number_text.to_s.strip
      fraction_text     = fraction_text.to_s.strip
      whole_number_text = nil if whole_number_text == ""
      fraction_text     = nil if fraction_text == ""

      # Fraction only (e.g. "1/2", "1/3")
      if whole_number_text.nil? && fraction_text.present?
        return [ nil, fraction_text ]
      end

      # Whole number only (e.g. "1", "2")
      if whole_number_text.present? && fraction_text.nil? && !whole_number_text.include?(".")
        return [ whole_number_text.to_f, nil ]
      end

      # Combined whole + fraction (e.g. "1" and "1/2")
      if whole_number_text.present? && fraction_text.present?
        return [ whole_number_text.to_f, fraction_text ]
      end

      # Decimal number (e.g. "1.5", "0.25")
      if whole_number_text&.include?(".")
        decimal = whole_number_text.to_f
        whole   = decimal.floor
        frac    = decimal - whole

        # Use FractionConverter to get a common fraction if possible
        fraction_str = convert_decimal_to_fraction(frac)

        if fraction_str
          quantity =
            if whole.positive?
              whole.to_f
            else
              nil
            end
          return [ quantity, fraction_str ]
        else
          # Fallback: keep decimal as quantity with no fraction
          return [ decimal, nil ]
        end
      end

      [ nil, nil ]
    end
  end
end
