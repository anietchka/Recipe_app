module Recipes
  class Cook
    include FractionConverter
    include UnitConverter

    def self.call(recipe, user)
      new(recipe, user).call
    end

    def initialize(recipe, user)
      @recipe = recipe
      @user = user
      @errors = {}
    end

    def call
      decrement_pantry_items
      create_or_update_cooked_recipe
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

      # Skip pantry items without quantity (base ingredients like salt, oil, etc.)
      # These are considered "infinite" and should not be decremented
      return if pantry_item.quantity.nil? && pantry_item.fraction.blank?

      # Convert required quantity to pantry item's unit
      required_in_pantry_unit = convert_quantity_to_pantry_unit(
        recipe_ingredient.required_quantity,
        recipe_ingredient.unit,
        pantry_item.unit
      )

      return unless required_in_pantry_unit

      current_quantity = pantry_item.available_quantity
      new_quantity_total = [ current_quantity - required_in_pantry_unit, 0.0 ].max
      new_quantity, new_fraction = convert_to_quantity_and_fraction(new_quantity_total)

      update_or_destroy_pantry_item(pantry_item, new_quantity, new_fraction)
    end

    def update_or_destroy_pantry_item(pantry_item, new_quantity, new_fraction)
      # If quantity reaches zero, delete the pantry item instead of keeping it with nil quantity
      if new_quantity.nil? && new_fraction.nil?
        pantry_item.destroy!
      else
        pantry_item.update!(quantity: new_quantity, fraction: new_fraction)
      end
    end

    def convert_quantity_to_pantry_unit(quantity, from_unit, to_unit)
      return quantity if from_unit == to_unit
      return quantity if from_unit.nil? || to_unit.nil?

      converted = convert_quantity(quantity, from_unit, to_unit)
      return converted if converted

      # If conversion fails, return nil to indicate incompatibility
      nil
    end

    def convert_to_quantity_and_fraction(decimal)
      return [ nil, nil ] if decimal.zero?

      whole = decimal.to_i
      decimal_part = decimal - whole

      # If we have a decimal part, try to convert it to a fraction
      if decimal_part > 0
        fraction = convert_decimal_to_fraction(decimal_part)
        if fraction
          # If whole is 0, return [nil, fraction], otherwise [whole, fraction]
          return whole.zero? ? [ nil, fraction ] : [ whole, fraction ]
        end
      end

      # If no fraction or whole is not zero, return whole as quantity
      return [ whole, nil ] if whole > 0

      # If decimal is between 0 and 1 and no common fraction matches, store as decimal
      [ decimal, nil ]
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
