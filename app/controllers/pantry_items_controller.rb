class PantryItemsController < ApplicationController
  include FractionConverter

  before_action :set_pantry_item, only: %i[destroy increment decrement]

  def index
    @pantry_items = current_user.pantry_items.includes(:ingredient).order(created_at: :desc)
    @pantry_item = PantryItem.new
    @common_fractions = FractionConverter::COMMON_FRACTIONS.values.sort
  end

  def create
    service_params = {
      ingredient_name: params[:pantry_item][:ingredient_name]&.strip,
      quantity: params[:pantry_item][:quantity],
      fraction: params[:pantry_item][:fraction],
      unit: params[:pantry_item][:unit]
    }

    result = PantryItems::Create.call(current_user, service_params)

    if result.success?
      redirect_to pantry_items_path, notice: t(".success")
    else
      @pantry_item = result.pantry_item || current_user.pantry_items.build(pantry_item_params)
      result.errors.each { |key, message| @pantry_item.errors.add(key, message) }
      @pantry_items = current_user.pantry_items.includes(:ingredient).order(created_at: :desc)
      @common_fractions = FractionConverter::COMMON_FRACTIONS.values.sort
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @pantry_item.destroy
    redirect_to pantry_items_path, notice: t(".success")
  end

  def increment
    current_quantity = @pantry_item.available_quantity
    new_quantity_total = current_quantity + 1.0
    new_quantity, new_fraction = convert_to_quantity_and_fraction(new_quantity_total)

    # If quantity becomes 0, we need to handle it differently
    # For increment, we should always have a quantity > 0
    if new_quantity.nil? && new_fraction.nil?
      new_quantity = 1.0
      new_fraction = nil
    end

    if @pantry_item.update(quantity: new_quantity, fraction: new_fraction)
      redirect_to pantry_items_path, notice: t(".success")
    else
      redirect_to pantry_items_path, alert: t(".error")
    end
  end

  def decrement
    current_quantity = @pantry_item.available_quantity
    new_quantity_total = [ current_quantity - 1.0, 0.0 ].max
    new_quantity, new_fraction = convert_to_quantity_and_fraction(new_quantity_total)

    # If quantity becomes 0, set both to nil (base ingredient)
    if new_quantity.nil? && new_fraction.nil?
      if @pantry_item.update(quantity: nil, fraction: nil)
        redirect_to pantry_items_path, notice: t(".success")
      else
        redirect_to pantry_items_path, alert: t(".error")
      end
    elsif @pantry_item.update(quantity: new_quantity, fraction: new_fraction)
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
    params.require(:pantry_item).permit(:ingredient_id, :quantity, :fraction, :unit)
  end

  def convert_to_quantity_and_fraction(decimal)
    return [ 0.0, nil ] if decimal.zero?

    whole = decimal.to_i
    decimal_part = decimal - whole

    return [ whole, nil ] if decimal_part.zero?

    # Try to convert decimal part to common fractions
    fraction = convert_decimal_to_fraction(decimal_part)
    return [ whole, fraction ] if fraction

    # If no common fraction matches, store as decimal in quantity
    [ decimal, nil ]
  end

  def convert_decimal_to_fraction(decimal)
    COMMON_FRACTIONS.each do |target_decimal, fraction|
      if (decimal - target_decimal).abs < 0.01
        return fraction
      end
    end

    nil
  end
end
