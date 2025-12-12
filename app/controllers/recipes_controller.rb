class RecipesController < ApplicationController
  before_action :set_recipe, only: %i[show cook]

  def index
    page = (filter_params[:page] || 1).to_i
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
    result = Recipes::Cook.call(@recipe, current_user)

    if result.success?
      redirect_to pantry_items_path, notice: t(".success")
    else
      Rails.logger.error "Failed to cook recipe: #{result.errors[:base]}"
      redirect_to recipe_path(@recipe), alert: t(".error")
    end
  end

  private

  def set_recipe
    @recipe = Recipe.find(params[:id])
  end

  def build_filters
    filters = {}
    filters[:min_rating] = filter_params[:min_rating].to_f if filter_params[:min_rating].present?
    filters[:max_prep_time] = filter_params[:max_prep_time].to_i if filter_params[:max_prep_time].present?
    filters[:max_cook_time] = filter_params[:max_cook_time].to_i if filter_params[:max_cook_time].present?
    filters
  end

  def filter_params
    params.permit(:page, :min_rating, :max_prep_time, :max_cook_time)
  end
end
