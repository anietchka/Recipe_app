class IngredientsController < ApplicationController
  def search
    query = params[:q].to_s.strip
    return render json: [] if query.blank?

    # Search ingredients by name (case-insensitive)
    ingredients = Ingredient.where("name ILIKE ?", "%#{query}%")
                           .order(:name)
                           .limit(10)
                           .pluck(:id, :name)

    render json: ingredients.map { |id, name| { id: id, name: name } }
  end
end
