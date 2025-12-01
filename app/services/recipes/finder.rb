module Recipes
  class Finder
    def self.call(user)
      new(user).call
    end

    def initialize(user)
      @user = user
    end

    def call
      sql = <<-SQL.squish
        SELECT recipes.id
        FROM recipes
        LEFT JOIN recipe_ingredients ON recipe_ingredients.recipe_id = recipes.id
        LEFT JOIN ingredients ON ingredients.id = recipe_ingredients.ingredient_id
        LEFT JOIN pantry_items ON pantry_items.ingredient_id = ingredients.id AND pantry_items.user_id = #{sanitize_user_id}
        GROUP BY recipes.id
        ORDER BY
          CASE WHEN COUNT(DISTINCT recipe_ingredients.id) = 0 THEN 1 ELSE 0 END,
          COUNT(DISTINCT CASE WHEN pantry_items.id IS NOT NULL THEN recipe_ingredients.id END) DESC,
          (COUNT(DISTINCT recipe_ingredients.id) - COUNT(DISTINCT CASE WHEN pantry_items.id IS NOT NULL THEN recipe_ingredients.id END)) ASC
      SQL

      recipe_ids = ActiveRecord::Base.connection.execute(sql).map { |row| row["id"] }

      return [] if recipe_ids.empty?

      # Preserve order using array_position in PostgreSQL
      Recipe.where(id: recipe_ids)
            .order(Arel.sql("array_position(ARRAY[#{recipe_ids.join(',')}]::bigint[], recipes.id)").asc)
    end

    private

    attr_reader :user

    def sanitize_user_id
      ActiveRecord::Base.connection.quote(user.id)
    end
  end
end
