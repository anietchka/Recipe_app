class PantryItem < ApplicationRecord
  include UnitConverter

  belongs_to :user
  belongs_to :ingredient

  validates :user, presence: true
  validates :ingredient, presence: true
  validates :quantity, numericality: { greater_than: 0 }, allow_nil: true
  validates :ingredient_id, uniqueness: { scope: :user_id }
  validates :unit, inclusion: { in: Ingredient::MEASUREMENT_UNITS }, allow_nil: true

  # Whether this pantry item covers what a recipe ingredient requires
  def sufficient_for?(recipe_ingredient)
    # Untracked stock: the user has the ingredient, we don't know how much
    return true if quantity.nil?

    # Recipe doesn't specify a quantity (e.g. "salt to taste"): having the ingredient is enough
    return true if recipe_ingredient.quantity.nil?

    available = quantity_in(recipe_ingredient.unit)

    # Units that can't be compared (e.g. g vs ml) are treated as missing
    available.present? && available >= recipe_ingredient.quantity
  end

  # Returns the quantity expressed in the given unit, or nil if the units can't be compared
  def quantity_in(target_unit)
    return quantity if unit == target_unit

    # A pantry quantity without unit is a count (e.g. "6 eggs" vs recipe "2 pcs")
    return quantity if unit.nil? && target_unit == "pcs"

    convert_quantity(quantity, unit, target_unit)
  end
end
