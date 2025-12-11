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

    # Main entry point:
    # returns a list of Recipe records, each enriched with calculated attributes via SQL:
    # - total_ingredients_count (automatically mapped from SQL AS alias)
    # - matched_ingredients_count (automatically mapped from SQL AS alias)
    # - missing_ingredients_count (automatically mapped from SQL AS alias)
    #
    # PERFORMANCE NOTE:
    # This implementation uses a highly optimized single SQL query to join recipes,
    # ingredients and user pantry items. It computes scores (matched/missing counts)
    # directly in the database using aggregation (GROUP BY).
    #
    # This ensures O(1) memory usage in Ruby regardless of the number of recipes,
    # avoiding the N+1 query problem typical of simple ActiveRecord iterations.
    # It scales well to thousands of recipes.
    #
    # ActiveRecord automatically maps SQL AS aliases to attributes on the model.
    # The Recipe model provides methods that convert these to integers.
    def call
      sql, bindings = sql_query_with_bindings
      rows = Recipe.find_by_sql([ sql ] + bindings)

      # ActiveRecord automatically maps SQL AS aliases to attributes
      # The Recipe model handles conversion to integers via read_attribute
      # All counts (total, matched, missing) are calculated in a single SQL query
      # This avoids N+1 queries and is highly performant
      rows
    end

    private

    attr_reader :user, :limit, :offset, :filters

    # Single SQL query that:
    # - starts from recipes
    # - joins all recipe_ingredients for each recipe
    # - LEFT JOINs the current user's pantry_items on ingredient_id
    # - applies optional filters on ratings, prep_time, and cook_time
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
    def sql_query_with_bindings
      where_conditions = []
      bindings = [ user.id ]

      # Apply filters if present
      if filters[:min_rating].present?
        where_conditions << "recipes.ratings >= ?"
        bindings << filters[:min_rating]
      end

      if filters[:max_prep_time].present?
        where_conditions << "recipes.prep_time <= ?"
        bindings << filters[:max_prep_time]
      end

      if filters[:max_cook_time].present?
        where_conditions << "recipes.cook_time <= ?"
        bindings << filters[:max_cook_time]
      end

      where_clause = where_conditions.any? ? "WHERE #{where_conditions.join(' AND ')}" : ""

      sql = <<~SQL
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
        #{where_clause}
        GROUP BY recipes.id
        ORDER BY
          matched_ingredients_count DESC,
          missing_ingredients_count ASC,
          recipes.id ASC
        LIMIT ? OFFSET ?
      SQL

      bindings << limit
      bindings << offset

      [ sql, bindings ]
    end
  end
end
