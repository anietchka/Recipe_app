class Recipe < ApplicationRecord
  include FractionConverter

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

      quantity_to_decrement = recipe_ingredient.required_quantity

      current_quantity = pantry_item.available_quantity

      new_quantity_total = [ current_quantity - quantity_to_decrement, 0.0 ].max

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
    elsif insufficient_quantity?(pantry_item, required_quantity)
      missing_total = required_quantity - pantry_item.available_quantity
      build_missing_hash(recipe_ingredient, missing_total)
    end
  end

  def insufficient_quantity?(pantry_item, required_quantity)
    pantry_item.available_quantity < required_quantity
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
  def convert_to_quantity_and_fraction(decimal)
    return [ 0.0, nil ] if decimal.zero?

    whole = decimal.to_i
    decimal_part = decimal - whole

    return [ whole, nil ] if decimal_part.zero?

    # Try to convert decimal part to common fractions
    fraction = convert_decimal_to_fraction(decimal_part)
    return [ whole, fraction ] if fraction

    # If no common fraction matches, store as decimal in quantity
    [ decimal, nil ]
  end
end
