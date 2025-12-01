class CreateIngredients < ActiveRecord::Migration[8.1]
  def change
    create_table :ingredients do |t|
      t.string :name
      t.string :canonical_name

      t.timestamps
    end
    add_index :ingredients, :canonical_name, unique: true
  end
end
