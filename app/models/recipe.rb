class Recipe < ApplicationRecord
  include UnitConverter

  has_many :recipe_ingredients, dependent: :destroy
  has_many :ingredients, through: :recipe_ingredients
  has_many :cooked_recipes, dependent: :destroy

  validates :title, presence: true

  # Returns the total number of ingredients for this recipe
  # Uses precalculated value from Recipes::Finder if available (from SQL query),
  # otherwise falls back to counting recipe_ingredients association
  def total_ingredients_count
    @total_ingredients_count ||= attributes["total_ingredients_count"]&.to_i
  end

  # Virtual attributes for precalculated scores from Recipes::Finder
  # These are automatically mapped by ActiveRecord from SQL AS aliases in find_by_sql
  # We access them via attributes hash and convert to integers
  def matched_ingredients_count
    @matched_ingredients_count ||= attributes["matched_ingredients_count"]&.to_i
  end

  def missing_ingredients_count
    @missing_ingredients_count ||= attributes["missing_ingredients_count"]&.to_i
  end

  # Returns recipe ingredients that are missing or insufficient in the user's pantry
  # Returns an array of hashes with:
  #   - ingredient_id: the ingredient ID
  #   - recipe_ingredient: the RecipeIngredient object
  #   - missing_quantity: the missing quantity (numeric, or nil if the recipe gives no quantity)
  def missing_ingredients_for(user)
    recipe_ingredients.includes(:ingredient).filter_map do |recipe_ingredient|
      calculate_missing_for_ingredient(recipe_ingredient, user)
    end
  end

  # Decrements pantry items for the given user based on recipe ingredients
  # Delegates to Recipes::Cook service
  # Raises RecipeError if the operation fails
  def cook!(user)
    result = Recipes::Cook.call(self, user)
    return if result.success?

    raise RecipeError, result.errors[:base] || "Failed to cook recipe"
  end

  private

  def calculate_missing_for_ingredient(recipe_ingredient, user)
    pantry_item = PantryItem.find_by(user: user, ingredient: recipe_ingredient.ingredient)
    required_quantity = recipe_ingredient.quantity

    if pantry_item.nil?
      build_missing_hash(recipe_ingredient, required_quantity)
    elsif pantry_item.quantity.nil?
      # PantryItem exists but has no quantity specified - consider it available
      # This means the user has the ingredient, even if we don't know how much
      nil
    elsif pantry_item.insufficient_quantity?(recipe_ingredient)
      # Convert pantry quantity to recipe unit for comparison
      available_in_recipe_unit = convert_quantity_to_recipe_unit(
        pantry_item.quantity,
        pantry_item.unit,
        recipe_ingredient.unit
      )

      if available_in_recipe_unit.nil?
        # Units incompatible (e.g., cup vs g), consider ingredient as available
        # We can't compare quantities, so assume the user has enough
        nil
      else
        missing_total = required_quantity - available_in_recipe_unit
        build_missing_hash(recipe_ingredient, missing_total) if missing_total > 0
      end
    end
  end



  def convert_quantity_to_recipe_unit(quantity, from_unit, to_unit)
    return quantity if from_unit == to_unit
    return quantity if from_unit.nil? || to_unit.nil?

    converted = convert_quantity(quantity, from_unit, to_unit)
    return converted if converted

    # If conversion fails, return nil to indicate incompatibility
    nil
  end

  def build_missing_hash(recipe_ingredient, missing_quantity)
    {
      ingredient_id: recipe_ingredient.ingredient_id,
      recipe_ingredient: recipe_ingredient,
      missing_quantity: missing_quantity
    }
  end
end
