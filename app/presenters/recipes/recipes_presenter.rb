module Recipes
  class RecipesPresenter
    attr_reader :recipes, :user, :page, :per_page, :total_count

    def initialize(recipes, user, page: 1, per_page: 20, total_count: recipes.size)
      @recipes = recipes
      @user = user
      @page = page
      @per_page = per_page
      @total_count = total_count
    end

    def presenters
      @presenters ||= recipes.map { |recipe| RecipePresenter.new(recipe, user) }
    end

    def any?
      recipes.any?
    end

    def has_more?
      page * per_page < total_count
    end

    def empty?
      recipes.empty?
    end

    def each(&block)
      presenters.each(&block)
    end
  end
end
