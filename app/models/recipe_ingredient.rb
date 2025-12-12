class RecipeIngredient < ApplicationRecord
  include QuantityCalculator

  belongs_to :recipe
  belongs_to :ingredient

  validates :recipe, presence: true
  validates :ingredient, presence: true
  validates :unit, inclusion: { in: Ingredient::MEASUREMENT_UNITS }, allow_nil: true

  # Returns the total required quantity for this recipe ingredient
  # Combines quantity and fraction, defaulting to 1.0 if both are nil/blank
  def required_quantity
    total = calculate_total_quantity(quantity, fraction)

    # Default to 1.0 if no quantity specified
    total.zero? && quantity.nil? && fraction.blank? ? 1.0 : total
  end

  private
end
