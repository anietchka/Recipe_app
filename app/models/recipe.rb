class Recipe < ApplicationRecord
  has_many :recipe_ingredients, dependent: :destroy
  has_many :ingredients, through: :recipe_ingredients
  has_many :cooked_recipes, dependent: :destroy

  validates :title, presence: true

  # Precalculated scores set by Recipes::Finder (nil when the recipe was not loaded through it)
  attr_accessor :total_ingredients_count, :matched_ingredients_count, :missing_ingredients_count

  # Returns recipe ingredients that are missing or insufficient in the user's pantry
  # Returns an array of hashes with:
  #   - ingredient_id: the ingredient ID
  #   - recipe_ingredient: the RecipeIngredient object
  #   - missing_quantity: the missing quantity (numeric, or nil if the recipe gives no quantity)
  def missing_ingredients_for(user, pantry_items = pantry_items_for(user))
    recipe_ingredients.includes(:ingredient).filter_map do |recipe_ingredient|
      calculate_missing_for_ingredient(recipe_ingredient, pantry_items[recipe_ingredient.ingredient_id])
    end
  end

  # The user's pantry items for this recipe's ingredients, indexed by ingredient_id (one query)
  def pantry_items_for(user)
    user.pantry_items.where(ingredient_id: recipe_ingredients.select(:ingredient_id)).index_by(&:ingredient_id)
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

  def calculate_missing_for_ingredient(recipe_ingredient, pantry_item)
    return build_missing_hash(recipe_ingredient, recipe_ingredient.quantity) if pantry_item.nil?
    return if pantry_item.sufficient_for?(recipe_ingredient)

    # Units that can't be compared: the whole recipe quantity is missing
    available = pantry_item.quantity_in(recipe_ingredient.unit)
    missing_quantity = available ? recipe_ingredient.quantity - available : recipe_ingredient.quantity

    build_missing_hash(recipe_ingredient, missing_quantity)
  end

  def build_missing_hash(recipe_ingredient, missing_quantity)
    {
      ingredient_id: recipe_ingredient.ingredient_id,
      recipe_ingredient: recipe_ingredient,
      missing_quantity: missing_quantity
    }
  end
end
