class RecipesController < ApplicationController
  DEFAULT_MAX_MISSING = 0
  MAX_MISSING_OPTIONS = (0..4)

  before_action :set_recipe, only: %i[show cook]

  def index
    page = (filter_params[:page] || 1).to_i
    per_page = 20
    offset = (page - 1) * per_page

    filters = build_filters
    @max_missing_selection = filters.fetch(:max_missing, "any").to_s
    @pagination_params = filter_params.except(:page)
    finder = Recipes::Finder.new(current_user, limit: per_page, offset: offset, filters: filters)
    recipes = finder.call
    @recipes_presenter = Recipes::RecipesPresenter.new(recipes, current_user, page: page, per_page: per_page, total_count: finder.total_count)
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
    max_missing = max_missing_filter
    filters[:max_missing] = max_missing unless max_missing.nil?
    filters
  end

  # "any" means no limit; a missing or invalid value falls back to the default
  def max_missing_filter
    value = filter_params.fetch(:max_missing, DEFAULT_MAX_MISSING.to_s)
    return nil if value == "any"

    number = Integer(value, exception: false)
    MAX_MISSING_OPTIONS.cover?(number) ? number : DEFAULT_MAX_MISSING
  end

  def filter_params
    params.permit(:page, :min_rating, :max_prep_time, :max_cook_time, :max_missing)
  end
end
