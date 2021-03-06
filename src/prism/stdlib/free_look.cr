require "crash"

module Prism
  # Causes the parent `Entity`'s position to be controlled by the mouse.
  class FreeLook < Crash::Component
    include Prism::InputReceiver
    include Prism::Adapter::GLFW
    Y_AXIS = Vector3f.new(0, 1, 0)
    @mouse_locked = false

    getter mouse_locked

    def initialize
      initialize(0.1375f32)
    end

    def initialize(sensitivity : Float32)
      initialize(sensitivity, Window::Key::Escape)
    end

    def initialize(@sensitivity : Float32, @unlock_mouse_key : Window::Key)
    end

    # Performs a rotation on the *transform*
    @[Override]
    def input!(tick : RenderLoop::Tick, input : RenderLoop::Input, entity : Crash::Entity)
      transform = entity.get(Prism::Transform).as(Prism::Transform)
      center_position = Vector2f.new(input.get_center[:x].to_f32, input.get_center[:y].to_f32)
      mouse_position = Vector2f.new(input.get_mouse_position[:x].to_f32, input.get_mouse_position[:y].to_f32)

      # un-lock the cursor
      if input.get_key(@unlock_mouse_key)
        input.set_cursor(true)
        @mouse_locked = false
      end

      # rotate
      if @mouse_locked
        delta_pos = mouse_position - center_position

        rot_y = delta_pos.x != 0
        rot_x = delta_pos.y != 0

        if rot_y
          transform.rotate(Y_AXIS, Prism::Maths.to_rad(delta_pos.x * @sensitivity))
        end
        if rot_x
          transform.rotate(transform.rot.right, Prism::Maths.to_rad(delta_pos.y * @sensitivity))
        end

        if rot_y || rot_x
          input.set_mouse_position(input.get_center)
        end
      end

      # lock the cursor
      if input.get_mouse_pressed(Window::MouseButton::Left)
        input.set_mouse_position(input.get_center)
        input.set_cursor(false)
        @mouse_locked = true
      end
    end
  end
end
