class IngredientsController < ApplicationController
  def search
    query = params[:q].to_s.strip
    return render json: [] if query.blank?

    # Use the autocomplete method with smart filtering and ordering
    ingredients = Ingredient.autocomplete(query, limit: 15)

    render json: ingredients.map { |ingredient| { id: ingredient.id, name: ingredient.name } }
  end
end
