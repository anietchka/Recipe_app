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

    def call
      # Sanitize inputs to prevent SQL injection
      user_id = user.id.to_i
      limit_value = @limit.to_i
      offset_value = @offset.to_i

      sql = <<-SQL.squish
        SELECT#{' '}
          recipes.id,
          recipes.title,
          recipes.cook_time,
          recipes.prep_time,
          recipes.image_url,
          recipes.category,
          recipes.ratings,
          recipes.created_at,
          recipes.updated_at,
          COUNT(DISTINCT recipe_ingredients.id) AS total_ingredients_count,
          COUNT(DISTINCT CASE WHEN pantry_items.id IS NOT NULL THEN recipe_ingredients.id END) AS matched_ingredients_count,
          (COUNT(DISTINCT recipe_ingredients.id) - COUNT(DISTINCT CASE WHEN pantry_items.id IS NOT NULL THEN recipe_ingredients.id END)) AS missing_ingredients_count
        FROM recipes
        LEFT JOIN recipe_ingredients ON recipe_ingredients.recipe_id = recipes.id
        LEFT JOIN ingredients ON ingredients.id = recipe_ingredients.ingredient_id
        LEFT JOIN pantry_items ON pantry_items.ingredient_id = ingredients.id AND pantry_items.user_id = ?
        GROUP BY recipes.id
        ORDER BY
          CASE WHEN COUNT(DISTINCT recipe_ingredients.id) = 0 THEN 1 ELSE 0 END,
          COUNT(DISTINCT CASE WHEN pantry_items.id IS NOT NULL THEN recipe_ingredients.id END) DESC,
          (COUNT(DISTINCT recipe_ingredients.id) - COUNT(DISTINCT CASE WHEN pantry_items.id IS NOT NULL THEN recipe_ingredients.id END)) ASC
        LIMIT ?
        OFFSET ?
      SQL

      # Use sanitize_sql_array to safely bind parameters
      safe_sql = ActiveRecord::Base.sanitize_sql_array([ sql, user_id, limit_value, offset_value ])
      results = ActiveRecord::Base.connection.execute(safe_sql)
      return [] if results.count == 0

      # Build Recipe objects with precalculated scores
      results.to_a.map do |row|
        recipe = Recipe.new(
          id: row["id"],
          title: row["title"],
          cook_time: row["cook_time"],
          prep_time: row["prep_time"],
          image_url: row["image_url"],
          category: row["category"],
          ratings: row["ratings"],
          created_at: row["created_at"],
          updated_at: row["updated_at"]
        )
        recipe.instance_variable_set(:@total_ingredients_count, row["total_ingredients_count"].to_i)
        recipe.instance_variable_set(:@matched_ingredients_count, row["matched_ingredients_count"].to_i)
        recipe.instance_variable_set(:@missing_ingredients_count, row["missing_ingredients_count"].to_i)
        recipe
      end
    end

    private

    attr_reader :user, :limit, :offset
  end
end
