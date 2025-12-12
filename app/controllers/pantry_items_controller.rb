class PantryItemsController < ApplicationController
  before_action :set_pantry_item, only: %i[destroy increment decrement]

  def index
    @pantry_items_presenter = PantryItems::PantryItemsPresenter.new(current_user)
  end

  def create
    result = PantryItems::Create.call(current_user, pantry_item_params.to_h.symbolize_keys)

    if result.success?
      redirect_to pantry_items_path, notice: t(".success")
    else
      pantry_item = result.pantry_item || current_user.pantry_items.build(pantry_item_params.except(:ingredient_name))
      result.errors.each { |key, message| pantry_item.errors.add(key, message) }
      @pantry_items_presenter = PantryItems::PantryItemsPresenter.new(current_user, pantry_item: pantry_item)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @pantry_item.destroy
    redirect_to pantry_items_path, notice: t(".success")
  end

  def increment
    result = PantryItems::UpdateQuantity.call(@pantry_item, :increment)

    if result.success?
      redirect_to pantry_items_path, notice: t(".success")
    else
      redirect_to pantry_items_path, alert: t(".error")
    end
  end

  def decrement
    result = PantryItems::UpdateQuantity.call(@pantry_item, :decrement)

    if result.success?
      redirect_to pantry_items_path, notice: t(".success")
    else
      redirect_to pantry_items_path, alert: t(".error")
    end
  end

  private

  def set_pantry_item
    @pantry_item = current_user.pantry_items.find(params[:id])
  end

  def pantry_item_params
    params.require(:pantry_item).permit(:ingredient_name, :quantity, :fraction, :unit)
  end
end
