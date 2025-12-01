class Recipe < ApplicationRecord
  include FractionConverter

  has_many :recipe_ingredients, dependent: :destroy
  has_many :ingredients, through: :recipe_ingredients

  validates :title, presence: true

  # Decrements pantry items for the given user based on recipe ingredients
  # - Uses recipe_ingredient.quantity if present, otherwise decrements by 1.0
  # - Handles fractions in both recipe_ingredient and pantry_item
  # - Never goes below 0
  # - Ignores ingredients not in the user's pantry
  def cook!(user)
    recipe_ingredients.each do |recipe_ingredient|
      pantry_item = PantryItem.find_by(
        user: user,
        ingredient: recipe_ingredient.ingredient
      )

      next unless pantry_item

      quantity_to_decrement = if recipe_ingredient.quantity.nil? && recipe_ingredient.fraction.blank?
                                 1.0
      else
                                 calculate_total_quantity(
                                   recipe_ingredient.quantity,
                                   recipe_ingredient.fraction
                                 )
      end

      current_quantity = calculate_total_quantity(
        pantry_item.quantity,
        pantry_item.fraction
      )

      new_quantity_total = [ current_quantity - quantity_to_decrement, 0.0 ].max

      new_quantity, new_fraction = convert_to_quantity_and_fraction(new_quantity_total)

      pantry_item.update!(quantity: new_quantity, fraction: new_fraction)
    end
  end

  private

  # Calculates total quantity from quantity and fraction
  # Converts fraction to decimal and adds to quantity
  def calculate_total_quantity(quantity, fraction)
    total = quantity.to_f

    return total if fraction.blank?

    fraction_value = parse_fraction(fraction)
    total += fraction_value if fraction_value

    total
  end

  # Parses a fraction string (e.g., "1/2", "3/4") and returns decimal value
  def parse_fraction(fraction_string)
    return nil if fraction_string.blank?

    parts = fraction_string.split("/")
    return nil unless parts.length == 2

    numerator = parts[0].to_f
    denominator = parts[1].to_f

    return nil if denominator.zero?

    numerator / denominator
  end

  # Converts a decimal to quantity and fraction
  # Returns [quantity, fraction] where fraction is a common fraction string or nil
  def convert_to_quantity_and_fraction(decimal)
    return [ 0.0, nil ] if decimal.zero?

    whole = decimal.to_i
    decimal_part = decimal - whole

    return [ whole, nil ] if decimal_part.zero?

    # Try to convert decimal part to common fractions
    fraction = convert_decimal_to_fraction(decimal_part)
    return [ whole, fraction ] if fraction

    # If no common fraction matches, store as decimal in quantity
    [ decimal, nil ]
  end
end
