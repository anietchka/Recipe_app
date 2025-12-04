class CookedRecipesController < ApplicationController
  def index
    cooked_recipes = current_user.cooked_recipes.includes(:recipe).order(cooked_at: :desc)
    recipes = cooked_recipes.map(&:recipe)
    @recipes_presenter = Recipes::RecipesPresenter.new(recipes, current_user, page: 1, per_page: recipes.count)
  end
end
