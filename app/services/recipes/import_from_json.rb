module Recipes
  class ImportFromJson
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
      canonical_name = Ingredient.canonicalize(ingredient_text)
      return if canonical_name.blank?

      ingredient = Ingredient.find_or_create_by!(canonical_name: canonical_name) do |ing|
        ing.name = ingredient_text
      end

      quantity, fraction, unit = parse_quantity_and_unit(ingredient_text)

      RecipeIngredient.create!(
        recipe: recipe,
        ingredient: ingredient,
        original_text: ingredient_text,
        quantity: quantity,
        fraction: fraction,
        unit: unit
      )
    end

    def parse_quantity_and_unit(text)
      text = normalize_fractions(text)
      match = match_ingredient_pattern(text)

      return [ nil, nil, nil ] unless match

      whole_number_text, fraction_text, unit = extract_matched_parts(match)

      # If we have a decimal, try to convert it to fraction
      if whole_number_text&.include?(".")
        decimal = whole_number_text.to_f
        converted = convert_decimal_to_fraction(decimal)

        # If conversion failed, return decimal as quantity
        return [ decimal, nil, unit ] if converted.nil?

        whole_number_text = converted[:whole].to_s
        fraction_text = converted[:fraction]
      end

      quantity = calculate_quantity(whole_number_text, fraction_text)
      [ quantity, fraction_text, unit ]
    end

    def match_ingredient_pattern(text)
      units_pattern = Ingredient::MEASUREMENT_UNITS.join("|")
      text.match(/^(\d+\.?\d*)?\s*(\d+\/\d+)?\s*(#{units_pattern})?/i)
    end

    def extract_matched_parts(match)
      whole_number_text = match[1]
      fraction_text = match[2]
      unit = match[3]&.downcase
      [ whole_number_text, fraction_text, unit ]
    end

    def convert_decimal_to_fraction(decimal)
      whole = decimal.to_i
      decimal_part = decimal - whole

      fraction_map = {
        0.5 => "1/2",
        0.333 => "1/3",
        0.667 => "2/3",
        0.25 => "1/4",
        0.75 => "3/4"
      }

      fraction_map.each do |target_decimal, fraction|
        if (decimal_part - target_decimal).abs < 0.01
          return { whole: whole, fraction: fraction }
        end
      end

      # If no common fraction matches, return nil to keep as decimal
      nil
    end

    def calculate_quantity(whole_number_text, fraction_text)
      whole_number = whole_number_text&.to_f || 0
      return nil if whole_number.zero? && fraction_text.nil?

      whole_number.zero? ? nil : whole_number
    end

    def normalize_fractions(text)
      # Map Unicode fractions to their decimal equivalents
      fraction_map = {
        "½" => " 1/2",
        "⅓" => " 1/3",
        "⅔" => " 2/3",
        "¼" => " 1/4",
        "¾" => " 3/4",
        "⅛" => " 1/8",
        "⅜" => " 3/8",
        "⅝" => " 5/8",
        "⅞" => " 7/8"
      }

      normalized = text.dup
      fraction_map.each do |unicode, replacement|
        normalized.gsub!(unicode, replacement)
      end

      normalized
    end
  end
end
