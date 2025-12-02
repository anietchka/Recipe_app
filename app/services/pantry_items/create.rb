module PantryItems
  class Create
    def self.call(user, params)
      new(user, params).call
    end

    def initialize(user, params)
      @user = user
      @params = params
      @errors = {}
    end

    def call
      ingredient = find_or_create_ingredient
      return build_error_result unless ingredient

      pantry_item = build_pantry_item(ingredient)
      return build_error_result(pantry_item) unless pantry_item.save

      build_success_result(pantry_item)
    end

    private

    attr_reader :user, :params, :errors

    def find_or_create_ingredient
      ingredient_name = params[:ingredient_name]&.strip

      if ingredient_name.blank?
        @errors[:ingredient] = "can't be blank"
        return nil
      end

      canonical_name = Ingredient.canonicalize(ingredient_name)
      if canonical_name.blank?
        @errors[:ingredient] = "is invalid"
        return nil
      end

      ingredient = Ingredient.find_or_create_by!(canonical_name: canonical_name) do |ing|
        ing.name = ingredient_name
      end

      # Update ingredient name if it was updated (e.g., better capitalization)
      ingredient.update(name: ingredient_name) if ingredient.name != ingredient_name

      ingredient
    end

    def build_pantry_item(ingredient)
      user.pantry_items.build(
        ingredient: ingredient,
        quantity: params[:quantity],
        fraction: params[:fraction],
        unit: params[:unit]
      )
    end

    def build_success_result(pantry_item)
      Result.new(success: true, pantry_item: pantry_item, errors: {})
    end

    def build_error_result(pantry_item = nil)
      item_errors = pantry_item&.errors&.to_hash || {}
      all_errors = errors.merge(item_errors)

      Result.new(success: false, pantry_item: pantry_item, errors: all_errors)
    end

    # Simple result object
    class Result
      attr_reader :pantry_item, :errors

      def initialize(success:, pantry_item:, errors:)
        @success = success
        @pantry_item = pantry_item
        @errors = errors
      end

      def success?
        @success
      end
    end
  end
end
