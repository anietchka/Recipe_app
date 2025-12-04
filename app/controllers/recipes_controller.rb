class RecipesController < ApplicationController
  before_action :set_recipe, only: %i[show cook]

  def index
    page = (params[:page] || 1).to_i
    per_page = 20
    offset = (page - 1) * per_page

    filters = build_filters
    recipes = Recipes::Finder.call(current_user, limit: per_page, offset: offset, filters: filters)
    @recipes_presenter = Recipes::RecipesPresenter.new(recipes, current_user, page: page, per_page: per_page)
  end

  def show
    @recipe_presenter = Recipes::RecipePresenter.new(@recipe, current_user)
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

  def build_filters
    filters = {}
    filters[:min_rating] = params[:min_rating].to_f if params[:min_rating].present?
    filters[:max_prep_time] = params[:max_prep_time].to_i if params[:max_prep_time].present?
    filters[:max_cook_time] = params[:max_cook_time].to_i if params[:max_cook_time].present?
    filters
  end
end
