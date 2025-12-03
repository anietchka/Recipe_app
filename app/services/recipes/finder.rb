module Recipes
  class Finder
    DEFAULT_LIMIT = 20
    DEFAULT_OFFSET = 0

    def self.call(user, limit: DEFAULT_LIMIT, offset: DEFAULT_OFFSET)
      new(user, limit: limit, offset: offset).call
    end

    def initialize(user, limit: DEFAULT_LIMIT, offset: DEFAULT_OFFSET)
      @user = user
      @limit = limit
      @offset = offset
    end

    # Main entry point:
    # returns a list of Recipe records, each enriched with:
    # - @total_ingredients_count
    # - @matched_ingredients_count
    # - @missing_ingredients_count
    #
    # These instance variables are later read in views via helpers or
    # small methods on the Recipe model (e.g. recipe.total_ingredients_count).
    def call
      rows = Recipe.find_by_sql([ sql_query, user.id, limit, offset ])

      rows.map do |recipe|
        # Extra columns come back as attributes on the AR object.
        # We store them in instance variables so that the Recipe model
        # can expose them via simple readers.
        recipe.instance_variable_set(
          :@total_ingredients_count,
          recipe["total_ingredients_count"].to_i
        )
        recipe.instance_variable_set(
          :@matched_ingredients_count,
          recipe["matched_ingredients_count"].to_i
        )
        recipe.instance_variable_set(
          :@missing_ingredients_count,
          recipe["missing_ingredients_count"].to_i
        )
        recipe
      end
    end

    private

    attr_reader :user, :limit, :offset

    # Single SQL query that:
    # - starts from recipes
    # - joins all recipe_ingredients for each recipe
    # - LEFT JOINs the current user's pantry_items on ingredient_id
    #
    # Because both RecipeIngredient and PantryItem reference Ingredient records
    # that were created using Ingredient.canonicalize, matching on ingredient_id
    # effectively means "match on canonical_name".
    #
    # For each recipe we compute:
    # - total_ingredients_count: how many ingredients the recipe needs
    # - matched_ingredients_count: how many of those are present in the user's pantry
    # - missing_ingredients_count: total - matched
    #
    # Then we order:
    # - recipes with more matches first (best fit),
    # - for equal matches, fewer missing ingredients first,
    # - finally by recipe id for stable ordering.
    def sql_query
      <<~SQL
        SELECT
          recipes.*,
          COUNT(DISTINCT ri_all.id) AS total_ingredients_count,
          COUNT(
            DISTINCT
            CASE
              WHEN pi.id IS NOT NULL THEN ri_all.id
              ELSE NULL
            END
          ) AS matched_ingredients_count,
          COUNT(DISTINCT ri_all.id)
            - COUNT(
                DISTINCT
                CASE
                  WHEN pi.id IS NOT NULL THEN ri_all.id
                  ELSE NULL
                END
              ) AS missing_ingredients_count
        FROM recipes
        JOIN recipe_ingredients AS ri_all
          ON ri_all.recipe_id = recipes.id
        LEFT JOIN pantry_items AS pi
          ON pi.ingredient_id = ri_all.ingredient_id
         AND pi.user_id = ?
        GROUP BY recipes.id
        ORDER BY
          matched_ingredients_count DESC,
          missing_ingredients_count ASC,
          recipes.id ASC
        LIMIT ? OFFSET ?
      SQL
    end
  end
end
