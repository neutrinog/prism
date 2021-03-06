require "crash"
require "./maths"

module Prism
  # Handles positional transformations
  class Transform < Crash::Component
    include Prism::Maths

    @pos : Vector3f
    @rot : Quaternion
    @scale : Vector3f

    @old_pos : Vector3f?
    @old_rot : Quaternion?
    @old_scale : Vector3f?

    getter pos, rot, scale
    setter pos, rot, scale

    def initialize
      @pos = Vector3f.new(0.0f32, 0.0f32, 0.0f32)
      @rot = Quaternion.new(0.0f64, 0.0f64, 0.0f64, 1.0f64)
      @scale = Vector3f.new(1.0f32, 1.0f32, 1.0f32)
    end

    def initialize(x : Float32, y : Float32, z : Float32)
      @pos = Vector3f.new(x, y, z)
      @rot = Quaternion.new(0.0f64, 0.0f64, 0.0f64, 1.0f64)
      @scale = Vector3f.new(1.0f32, 1.0f32, 1.0f32)
    end

    def rotate(axis : Vector3f, angle : Float32)
      @rot = (Quaternion.new(axis, angle) * @rot).normalize
    end

    # Rotates to look at the *object*
    def look_at(object : Prism::Entity)
      @rot = get_look_at_direction(object.get(Prism::Transform).as(Prism::Transform).pos, @rot.up)
      self
    end

    # Rotates to look at the *transform*
    def look_at(transform : Prism::Transform)
      @rot = get_look_at_direction(transform.pos, @rot.up)
      self
    end

    # Rotates to look at the point
    def look_at(point : Vector3f, up : Vector3f)
      @rot = get_look_at_direction(point, up)
      self
    end

    # Creates a transformation to look at a point
    # This is handy for applying some form of lerp'ing.
    def get_look_at_direction(point : Vector3f, up : Vector3f) : Quaternion
      return Quaternion.new(Matrix4f.new.init_rotation((point - @pos).to_normalized, up))
    end

    # Returns the transformation
    def get_transformation : Matrix4f
      translation_matrix = Matrix4f.new.init_translation(@pos.x, @pos.y, @pos.z)
      rotation_matrix = @rot.to_rotation_matrix
      scale_matrix = Matrix4f.new.init_scale(@scale.x, @scale.y, @scale.z)

      return translation_matrix * rotation_matrix * scale_matrix
    end
  end

  class Transform < Crash::Component
    def scale(factor : Float32)
      @scale *= factor
    end

    # Elevates the object to the exact position
    def elevate_to(position : Float32)
      @pos.y = position
      self
    end

    # Changes the object's elevation by the distance
    def elevate_by(amount : Float32)
      @pos.y += amount
      self
    end

    # Rotates the shape around the x-axis
    def rotate_x_axis(angle : Angle)
      rotate(Vector3f.new(1, 0, 0), angle.radians)
      self
    end

    # Rotates the shape around the y-axis
    def rotate_y_axis(angle : Angle)
      rotate(Vector3f.new(0, 1, 0), angle.radians)
      self
    end

    # Rotates the shape around the z-axis
    def rotate_z_axis(angle : Angle)
      rotate(Vector3f.new(0, 0, 1), angle.radians)
      self
    end

    # Moves the shape towards north by the *distance*
    def move_north(distance : Float32)
      @pos = @pos + Vector3f.new(0, 0, 1) * distance
      self
    end

    def move_south(distance : Float32)
      move_north(-distance)
      self
    end

    # Moves the shape towards east by the *distance*
    def move_east(distance : Float32)
      @pos = @pos + Vector3f.new(1, 0, 0) * distance
      self
    end

    def move_west(distance : Float32)
      move_east(-distance)
      self
    end

    def move_to(x : Float32, y : Float32, z : Float32)
      @pos.x = x
      @pos.y = y
      @pos.z = z
      self
    end

    def move_to(entity : Crash::Entity)
      if entity.has Prism::Transform
        pos = entity.get(Prism::Transform).as(Prism::Transform).pos
        move_to(pos.x, pos.y, pos.z)
      end
      self
    end
  end
end
