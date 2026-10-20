module Recipes
  class Cook
    def self.call(recipe, user)
      new(recipe, user).call
    end

    def initialize(recipe, user)
      @recipe = recipe
      @user = user
      @errors = {}
    end

    # Pantry updates and the CookedRecipe are written atomically:
    # if any write fails, every pantry change is rolled back.
    def call
      ActiveRecord::Base.transaction do
        decrement_pantry_items
        create_or_update_cooked_recipe
      end
      build_success_result
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed => e
      build_error_result(e)
    end

    private

    attr_reader :recipe, :user, :errors

    def decrement_pantry_items
      recipe.recipe_ingredients.each do |recipe_ingredient|
        decrement_pantry_item_for_ingredient(recipe_ingredient)
      end
    end

    def decrement_pantry_item_for_ingredient(recipe_ingredient)
      pantry_item = PantryItem.find_by(
        user: user,
        ingredient: recipe_ingredient.ingredient
      )

      return unless pantry_item

      # Skip pantry items with untracked quantities.
      # The user has the ingredient, but we don't know the exact stock.
      return if pantry_item.quantity.nil?

      # Skip when the recipe gives no quantity (e.g. "salt to taste")
      # or when the units can't be compared (never invent a conversion)
      consumed = pantry_item.quantity_consumed_by(recipe_ingredient)
      return unless consumed

      update_or_destroy_pantry_item(pantry_item, pantry_item.quantity - consumed)
    end

    def update_or_destroy_pantry_item(pantry_item, new_quantity)
      # Exhausted (or insufficient) stock: remove the item rather than storing zero or a negative quantity
      if new_quantity <= 0
        pantry_item.destroy!
      else
        pantry_item.update!(quantity: new_quantity)
      end
    end

    def create_or_update_cooked_recipe
      cooked_recipe = CookedRecipe.find_or_initialize_by(user: user, recipe: recipe)
      cooked_recipe.cooked_at = Time.current
      cooked_recipe.save!
    end

    def build_success_result
      Result.new(success: true, recipe: recipe, errors: {})
    end

    def build_error_result(exception)
      @errors[:base] = exception.message
      Result.new(success: false, recipe: recipe, errors: errors)
    end

    # Simple result object
    class Result
      attr_reader :recipe, :errors

      def initialize(success:, recipe:, errors:)
        @success = success
        @recipe = recipe
        @errors = errors
      end

      def success?
        @success
      end
    end
  end
end
