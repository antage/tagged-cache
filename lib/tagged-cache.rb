require "active_support"

ActiveSupport.on_load(:action_controller) do
  require "tagged-cache/action_controller"
end
