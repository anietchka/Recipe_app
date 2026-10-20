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
    return quantity if same_unit_as?(target_unit)

    convert_quantity(quantity, unit, target_unit)
  end

  # How much of this item a recipe ingredient consumes, expressed in this item's unit.
  # nil when the recipe gives no quantity or the units can't be compared.
  def quantity_consumed_by(recipe_ingredient)
    return recipe_ingredient.quantity if same_unit_as?(recipe_ingredient.unit)

    convert_quantity(recipe_ingredient.quantity, recipe_ingredient.unit, unit)
  end

  private

  # Same unit, or a pantry quantity without unit counted against "pcs" (e.g. "6 eggs" vs recipe "2 pcs")
  def same_unit_as?(other_unit)
    unit == other_unit || (unit.nil? && other_unit == "pcs")
  end
end
