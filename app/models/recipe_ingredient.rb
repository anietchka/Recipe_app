class RecipeIngredient < ApplicationRecord
  belongs_to :recipe
  belongs_to :ingredient

  validates :recipe, presence: true
  validates :ingredient, presence: true
  validates :unit, inclusion: { in: Ingredient::MEASUREMENT_UNITS }, allow_nil: true
end
