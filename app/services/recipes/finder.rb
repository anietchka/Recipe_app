module Recipes
  class Finder
    DEFAULT_LIMIT = 20
    DEFAULT_OFFSET = 0
    DEFAULT_FILTERS = {}.freeze

    def self.call(user, limit: DEFAULT_LIMIT, offset: DEFAULT_OFFSET, filters: DEFAULT_FILTERS)
      new(user, limit: limit, offset: offset, filters: filters).call
    end

    def initialize(user, limit: DEFAULT_LIMIT, offset: DEFAULT_OFFSET, filters: DEFAULT_FILTERS)
      @user = user
      @limit = limit
      @offset = offset
      @filters = filters
    end

    # Returns a page of Recipe records ranked for the user's pantry, each with
    # total_ingredients_count, matched_ingredients_count and missing_ingredients_count set.
    #
    # An ingredient is matched when PantryItem#sufficient_for? says so, which is the
    # same rule the recipe detail uses (Recipe#missing_ingredients_for).
    #
    # Ranking: more matched ingredients first, then fewer missing, then recipe id.
    #
    # Runs a fixed number of queries; only recipe ingredients present in the pantry are
    # loaded, the others are counted in the database.
    def call
      pantry_items = user.pantry_items.index_by(&:ingredient_id)
      recipes = filtered_recipes

      total_counts = RecipeIngredient.where(recipe: recipes).group(:recipe_id).count
      matched_counts = RecipeIngredient
        .where(recipe: recipes, ingredient_id: pantry_items.keys)
        .select do |recipe_ingredient|
          pantry_item = pantry_items[recipe_ingredient.ingredient_id]
          pantry_item.sufficient_for?(recipe_ingredient)
        end
        .map(&:recipe_id)
        .tally

      ranked_ids = total_counts.keys.sort_by do |id|
        matched = matched_counts.fetch(id, 0)
        [ -matched, total_counts[id] - matched, id ]
      end
      page_ids = ranked_ids.drop(offset).first(limit)

      recipes_by_id = Recipe.where(id: page_ids).index_by(&:id)
      page_ids.map do |id|
        recipes_by_id[id].tap do |recipe|
          recipe.total_ingredients_count = total_counts[id]
          recipe.matched_ingredients_count = matched_counts.fetch(id, 0)
          recipe.missing_ingredients_count = recipe.total_ingredients_count - recipe.matched_ingredients_count
        end
      end
    end

    private

    attr_reader :user, :limit, :offset, :filters

    def filtered_recipes
      recipes = Recipe.all
      recipes = recipes.where("ratings >= ?", filters[:min_rating]) if filters[:min_rating].present?
      recipes = recipes.where("prep_time <= ?", filters[:max_prep_time]) if filters[:max_prep_time].present?
      recipes = recipes.where("cook_time <= ?", filters[:max_cook_time]) if filters[:max_cook_time].present?
      recipes
    end
  end
end
