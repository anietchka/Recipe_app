class CreateRecipes < ActiveRecord::Migration[8.1]
  def change
    create_table :recipes do |t|
      t.string :title
      t.text :description
      t.text :instructions
      t.integer :total_time_minutes
      t.string :image_url
      t.string :source_url
      t.decimal :rating
      t.integer :ratings_count

      t.timestamps
    end
  end
end
