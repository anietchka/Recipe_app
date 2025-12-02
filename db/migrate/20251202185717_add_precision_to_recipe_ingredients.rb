class AddPrecisionToRecipeIngredients < ActiveRecord::Migration[8.1]
  def change
    add_column :recipe_ingredients, :precision, :string
  end
end
