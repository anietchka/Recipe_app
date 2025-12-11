module Recipes
  class RecipePresenter
    attr_reader :recipe, :user
    delegate :id, :to_param, :title, :cook_time, :prep_time, :image_url, :category, :ratings, :created_at, :updated_at, to: :recipe

    def initialize(recipe, user)
      @recipe = recipe
      @user = user
    end

    def missing_ingredients
      @missing_ingredients ||= recipe.missing_ingredients_for(user)
    end

    # Returns available ingredients with their pantry items
    # Returns an array of hashes with:
    #   - recipe_ingredient: the RecipeIngredient object
    #   - pantry_item: the PantryItem object (or nil)
    def available_ingredients
      @available_ingredients ||= begin
        missing_ingredient_ids = missing_ingredients.map { |m| m[:ingredient_id] }

        recipe_ingredients.filter_map do |recipe_ingredient|
          next if missing_ingredient_ids.include?(recipe_ingredient.ingredient_id)

          pantry_item = PantryItem.find_by(user: user, ingredient: recipe_ingredient.ingredient)

          {
            recipe_ingredient: recipe_ingredient,
            pantry_item: pantry_item
          }
        end
      end
    end

    def recipe_ingredients
      @recipe_ingredients ||= recipe.recipe_ingredients.includes(:ingredient)
    end

    def has_time_info?
      prep_time.present? || cook_time.present?
    end

    def has_ratings?
      ratings.present?
    end

    def has_category?
      category.present?
    end

    def has_cook_time?
      cook_time.present?
    end

    def has_prep_time?
      prep_time.present?
    end

    def has_image_url?
      image_url.present?
    end

    def total_ingredients_count
      # Uses precalculated value from Recipes::Finder if available, otherwise counts
      count = recipe.total_ingredients_count
      count.nil? ? recipe_ingredients.count : count
    end

    def matched_ingredients
      # Use precalculated value from Recipes::Finder if available
      recipe.matched_ingredients_count || (total_ingredients_count - missing_count)
    end

    def missing_count
      # Use precalculated value from Recipes::Finder if available
      recipe.missing_ingredients_count || missing_ingredients.count
    end

    def no_available_ingredients?
      matched_ingredients.zero?
    end

    def completion_percentage
      return 0 if total_ingredients_count.zero?

      (matched_ingredients.to_f / total_ingredients_count * 100).round
    end

    def status_class
      if missing_count == 0
        "recipe-status--ready"
      elsif missing_count <= 3
        "recipe-status--almost"
      else
        "recipe-status--shopping"
      end
    end

    def status_text
      if missing_count == 0
        I18n.t("recipes.index.status_ready")
      elsif missing_count <= 3
        I18n.t("recipes.index.status_almost")
      else
        I18n.t("recipes.index.status_shopping")
      end
    end

    # Format ingredient quantity for display
    def format_ingredient_quantity(recipe_ingredient)
      parts = []
      if recipe_ingredient.quantity.present? && recipe_ingredient.quantity > 0
        parts << recipe_ingredient.quantity.to_s
      end
      if recipe_ingredient.fraction.present?
        parts << recipe_ingredient.fraction
      end
      if recipe_ingredient.unit.present?
        parts << recipe_ingredient.unit
      end
      if parts.empty? && recipe_ingredient.original_text.present?
        return recipe_ingredient.original_text
      end
      parts.join(" ")
    end

    # Format pantry item quantity for display
    def format_pantry_quantity(pantry_item)
      parts = []
      if pantry_item.quantity.present? && pantry_item.quantity > 0
        parts << pantry_item.quantity.to_s
      end
      if pantry_item.fraction.present?
        parts << pantry_item.fraction
      end
      if pantry_item.unit.present?
        parts << pantry_item.unit
      end
      parts.empty? ? I18n.t("recipes.show.present") : parts.join(" ")
    end

    # Format missing quantity for display
    def format_missing_quantity(missing_info)
      parts = []
      if missing_info[:missing_quantity].present? && missing_info[:missing_quantity] > 0
        parts << missing_info[:missing_quantity].to_s
      end
      if missing_info[:missing_fraction].present?
        parts << missing_info[:missing_fraction]
      end
      # Use the recipe ingredient's unit for the missing quantity
      recipe_ingredient = missing_info[:recipe_ingredient]
      if recipe_ingredient&.unit.present?
        parts << recipe_ingredient.unit
      end
      parts.join(" ")
    end
  end
end
