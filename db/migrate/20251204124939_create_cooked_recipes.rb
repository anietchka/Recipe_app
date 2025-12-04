class CreateCookedRecipes < ActiveRecord::Migration[8.1]
  def change
    create_table :cooked_recipes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :recipe, null: false, foreign_key: true
      t.datetime :cooked_at, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end
  end
end
