class RecipesController < ApplicationController
  before_action :set_recipe, only: %i[show cook]

  def index
    @page = (params[:page] || 1).to_i
    @per_page = 20
    @offset = (@page - 1) * @per_page

    recipes = Recipes::Finder.call(current_user, limit: @per_page, offset: @offset)
    @recipes = recipes.map { |recipe| RecipeDecorator.new(recipe) }

    # Calculate total count for pagination (simplified: if we got less than per_page, we're on last page)
    @has_more = recipes.count == @per_page
  end

  def show
    @missing_ingredients = @recipe.missing_ingredients_for(current_user)

    # Calculate scores for the decorator
    # Count total ingredients
    total_count = @recipe.recipe_ingredients.count

    # Count matched ingredients: ingredients NOT in @missing_ingredients
    # @missing_ingredients contains only ingredients that are missing or insufficient
    # So matched = total - missing
    missing_count = @missing_ingredients.count
    matched_count = total_count - missing_count

    # Set instance variables for decorator
    @recipe.instance_variable_set(:@total_ingredients_count, total_count)
    @recipe.instance_variable_set(:@matched_ingredients_count, matched_count)
    @recipe.instance_variable_set(:@missing_ingredients_count, missing_count)
  end

  def cook
    @recipe.cook!(current_user)
    redirect_to pantry_items_path, notice: t(".success")
  rescue StandardError => e
    Rails.logger.error "Failed to cook recipe: #{e.message}"
    redirect_to recipe_path(@recipe), alert: t(".error")
  end

  private

  def set_recipe
    @recipe = Recipe.find(params[:id])
  end
end
