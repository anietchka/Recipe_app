class RemovePrecisionFromRecipeIngredients < ActiveRecord::Migration[8.1]
  def change
    remove_column :recipe_ingredients, :precision, :string
  end
end
