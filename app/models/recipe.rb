class Recipe < ApplicationRecord
  include FractionConverter
  include UnitConverter

  has_many :recipe_ingredients, dependent: :destroy
  has_many :ingredients, through: :recipe_ingredients

  validates :title, presence: true

  # Returns recipe ingredients that are missing or insufficient in the user's pantry
  # Returns an array of hashes with:
  #   - ingredient_id: the ingredient ID
  #   - recipe_ingredient: the RecipeIngredient object
  #   - missing_quantity: the missing quantity (float)
  #   - missing_fraction: the missing fraction (string or nil)
  def missing_ingredients_for(user)
    recipe_ingredients.includes(:ingredient).filter_map do |recipe_ingredient|
      calculate_missing_for_ingredient(recipe_ingredient, user)
    end
  end

  # Decrements pantry items for the given user based on recipe ingredients
  # - Uses recipe_ingredient.quantity if present, otherwise decrements by 1.0
  # - Handles fractions in both recipe_ingredient and pantry_item
  # - Never goes below 0
  # - Ignores ingredients not in the user's pantry
  def cook!(user)
    recipe_ingredients.each do |recipe_ingredient|
      pantry_item = PantryItem.find_by(
        user: user,
        ingredient: recipe_ingredient.ingredient
      )

      next unless pantry_item

      # Skip pantry items without quantity (base ingredients like salt, oil, etc.)
      # These are considered "infinite" and should not be decremented
      if pantry_item.quantity.nil? && pantry_item.fraction.blank?
        next
      end

      # Convert required quantity to pantry item's unit
      required_quantity = recipe_ingredient.required_quantity
      required_in_pantry_unit = convert_quantity_to_pantry_unit(
        required_quantity,
        recipe_ingredient.unit,
        pantry_item.unit
      )

      next unless required_in_pantry_unit

      current_quantity = pantry_item.available_quantity

      new_quantity_total = [ current_quantity - required_in_pantry_unit, 0.0 ].max

      new_quantity, new_fraction = convert_to_quantity_and_fraction(new_quantity_total)

      pantry_item.update!(quantity: new_quantity, fraction: new_fraction)
    end
  end

  private

  def calculate_missing_for_ingredient(recipe_ingredient, user)
    pantry_item = PantryItem.find_by(user: user, ingredient: recipe_ingredient.ingredient)
    required_quantity = recipe_ingredient.required_quantity

    if pantry_item.nil?
      build_missing_hash(recipe_ingredient, required_quantity)
    elsif pantry_item_without_quantity?(pantry_item)
      # PantryItem exists but has no quantity specified - consider it available
      # This means the user has the ingredient, even if we don't know how much
      nil
    elsif insufficient_quantity?(recipe_ingredient, pantry_item)
      # Convert pantry quantity to recipe unit for comparison
      available_in_recipe_unit = convert_quantity_to_recipe_unit(
        pantry_item.available_quantity,
        pantry_item.unit,
        recipe_ingredient.unit
      )

      if available_in_recipe_unit.nil?
        # Units incompatible, treat as missing
        build_missing_hash(recipe_ingredient, required_quantity)
      else
        missing_total = required_quantity - available_in_recipe_unit
        build_missing_hash(recipe_ingredient, missing_total) if missing_total > 0
      end
    end
  end

  def pantry_item_without_quantity?(pantry_item)
    # Check if pantry item has no quantity specified (both quantity and fraction are nil/blank)
    pantry_item.quantity.nil? && pantry_item.fraction.blank?
  end

  def insufficient_quantity?(recipe_ingredient, pantry_item)
    # If no units specified, compare directly
    if pantry_item.unit.nil? && recipe_ingredient.unit.nil?
      return recipe_ingredient.required_quantity > pantry_item.available_quantity
    end

    # If one has unit and other doesn't, treat as insufficient (can't compare)
    return true if pantry_item.unit.nil? || recipe_ingredient.unit.nil?

    # If units are incompatible, treat as insufficient
    return true unless units_compatible?(pantry_item.unit, recipe_ingredient.unit)

    # Convert pantry quantity to recipe unit for comparison
    available_in_recipe_unit = convert_quantity(
      pantry_item.available_quantity,
      pantry_item.unit,
      recipe_ingredient.unit
    )

    return true unless available_in_recipe_unit

    recipe_ingredient.required_quantity > available_in_recipe_unit
  end

  def convert_quantity_to_recipe_unit(quantity, from_unit, to_unit)
    return quantity if from_unit == to_unit
    return quantity if from_unit.nil? || to_unit.nil?

    converted = convert_quantity(quantity, from_unit, to_unit)
    return converted if converted

    # If conversion fails, return nil to indicate incompatibility
    nil
  end

  def convert_quantity_to_pantry_unit(quantity, from_unit, to_unit)
    return quantity if from_unit == to_unit
    return quantity if from_unit.nil? || to_unit.nil?

    converted = convert_quantity(quantity, from_unit, to_unit)
    return converted if converted

    # If conversion fails, return nil to indicate incompatibility
    nil
  end

  def build_missing_hash(recipe_ingredient, missing_total)
    missing_quantity, missing_fraction = convert_to_quantity_and_fraction(missing_total)

    {
      ingredient_id: recipe_ingredient.ingredient_id,
      recipe_ingredient: recipe_ingredient,
      missing_quantity: missing_quantity,
      missing_fraction: missing_fraction
    }
  end

  # Converts a decimal to quantity and fraction
  # Returns [quantity, fraction] where fraction is a common fraction string or nil
  # Returns [nil, nil] if decimal is zero (to allow pantry items without quantity)
  # Returns [nil, fraction] if decimal is a fraction between 0 and 1
  def convert_to_quantity_and_fraction(decimal)
    return [ nil, nil ] if decimal.zero?

    whole = decimal.to_i
    decimal_part = decimal - whole

    # If we have a decimal part, try to convert it to a fraction
    if decimal_part > 0
      fraction = convert_decimal_to_fraction(decimal_part)
      if fraction
        # If whole is 0, return [nil, fraction], otherwise [whole, fraction]
        return whole.zero? ? [ nil, fraction ] : [ whole, fraction ]
      end
    end

    # If no fraction or whole is not zero, return whole as quantity
    return [ whole, nil ] if whole > 0

    # If decimal is between 0 and 1 and no common fraction matches, store as decimal
    [ decimal, nil ]
  end
end
