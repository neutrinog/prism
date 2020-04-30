require "crash"
require "annotation"
require "./render_system/**"

module Prism::Systems
  # A default system for rendering `Prism::Entity`s.
  class RenderSystem < Crash::System
    # RGB
    SKY_COLOR = Vector3f.new(0.6, 0.8, 1)
    @entities : Array(Crash::Entity)
    @grouped_entities : Hash(Prism::TexturedModel, Array(Crash::Entity))
    @terrains : Array(Crash::Entity)
    @lights : Array(Crash::Entity)
    @cameras : Array(Crash::Entity)

    @entity_shader : Prism::Shader::EntityShader = Prism::Shader::EntityShader.new
    @entity_renderer : Prism::Systems::EntityRenderer

    @terrain_shader : Prism::Shader::TerrainShader = Prism::Shader::TerrainShader.new
    @terrain_renderer : Prism::Systems::TerrainRenderer

    def initialize
      @entity_renderer = Prism::Systems::EntityRenderer.new(@entity_shader)
      @terrain_renderer = Prism::Systems::TerrainRenderer.new(@terrain_shader)
      @entities = [] of Crash::Entity
      @grouped_entities = {} of Prism::TexturedModel => Array(Crash::Entity)
      @terrains = [] of Crash::Entity
      @lights = [] of Crash::Entity
      @cameras = [] of Crash::Entity
    end

    @[Override]
    def add_to_engine(engine : Crash::Engine)
      @terrains = engine.get_entities Prism::Terrain
      @entities = engine.get_entities Prism::TexturedModel
      # TODO: just get the lights within range
      @lights = engine.get_entities Prism::DirectionalLight
      @cameras = engine.get_entities Prism::Camera
    end

    # Uses the transformation of the *entity* to calculate the view that the camera has of the world.
    # This allows you to attach the camera view to any entity
    def calculate_view_matrix(entity : Crash::Entity)
      transform = entity.get(Prism::Transform).as(Prism::Transform)
      camera_rotation = transform.get_transformed_rot.conjugate.to_rotation_matrix
      camera_pos = transform.get_transformed_pos * -1
      camera_translation = Matrix4f.new.init_translation(camera_pos.x, camera_pos.y, camera_pos.z)
      camera_rotation * camera_translation
    end

    # Sorts the entities into groups of `TexturedModel`s and puts them into @grouped_entities
    def batch_entities(entities : Array(Crash::Entity))
      entities.each do |entity|
        model = entity.get(Prism::TexturedModel).as(Prism::TexturedModel)
        if @grouped_entities.has_key? model
          @grouped_entities[model] << entity
        else
          @grouped_entities[model] = [entity] of Crash::Entity
        end
      end
    end

    # Handles the rendering.
    # TODO: this is a little verbose and needs to be cleaned up a bit.
    @[Override]
    def update(time : Float64)
      batch_entities(@entities)

      # calculate camera matricies
      cam_entity = @cameras[0]
      cam = cam_entity.get(Prism::Camera).as(Prism::Camera)
      projection_matrix = cam.get_projection
      view_matrix = calculate_view_matrix(cam_entity)
      eye_pos = cam_entity.get(Prism::Transform).as(Prism::Transform).get_transformed_pos

      # start shading
      prepare

      #
      # entities
      #
      @entity_shader.start
      # TODO: should we pass the projection matrix to the renderer?
      #  Also, should we calculate this just once? We could take this out of the camera.
      @entity_shader.projection_matrix = projection_matrix
      @entity_shader.view_matrix = view_matrix
      @entity_shader.eye_pos = eye_pos
      @entity_shader.sky_color = SKY_COLOR
      if @lights.size > 0
        light_entity = @lights[0]
        light_transform = light_entity.get(Prism::Transform).as(Prism::Transform)
        @entity_shader.light = light_entity.get(Prism::DirectionalLight).as(Prism::DirectionalLight)
        # TRICKY: this is a temporary hack to help decouple entities from lights.
        #  We'll need a better solution later. We could potentially pass the light
        #  entity to the shader so it can set the proper uniforms.
        @entity_shader.set_uniform("light.direction", light_transform.get_transformed_rot.forward)
      end
      @entity_renderer.render(@grouped_entities)
      @grouped_entities.clear
      @entity_shader.stop

      #
      # terrain
      #
      @terrain_shader.start
      @terrain_shader.projection_matrix = projection_matrix
      @terrain_shader.view_matrix = view_matrix
      @terrain_shader.eye_pos = eye_pos
      @terrain_shader.sky_color = SKY_COLOR
      if @lights.size > 0
        light_entity = @lights[0]
        light_transform = light_entity.get(Prism::Transform).as(Prism::Transform)
        @terrain_shader.light = light_entity.get(Prism::DirectionalLight).as(Prism::DirectionalLight)
        # TRICKY: this is a temporary hack to help decouple entities from lights.
        #  We'll need a better solution later. We could potentially pass the light
        #  entity to the shader so it can set the proper uniforms.
        @terrain_shader.set_uniform("light.direction", light_transform.get_transformed_rot.forward)
      end
      @terrain_renderer.render(@terrains)
      @terrain_shader.stop
    end

    @[Override]
    def remove_from_engine(engine : Crash::Engine)
      @entities.clear
      @lights.clear
      @cameras.clear
    end

    def prepare
      LibGL.clear(LibGL::COLOR_BUFFER_BIT | LibGL::DEPTH_BUFFER_BIT)

      LibGL.enable(LibGL::BLEND)
      LibGL.blend_equation(LibGL::FUNC_ADD)
      LibGL.blend_func(LibGL::ONE, LibGL::ONE_MINUS_SRC_ALPHA)

      LibGL.depth_mask(LibGL::FALSE)
      LibGL.depth_func(LibGL::EQUAL)

      LibGL.depth_func(LibGL::LESS)
      LibGL.depth_mask(LibGL::TRUE)
      LibGL.disable(LibGL::BLEND)

      LibGL.clear_color(SKY_COLOR.x, SKY_COLOR.y, SKY_COLOR.z, 1f32)
      LibGL.front_face(LibGL::CW)
      LibGL.cull_face(LibGL::BACK)
      LibGL.enable(LibGL::CULL_FACE)
      LibGL.enable(LibGL::DEPTH_TEST)
      LibGL.enable(LibGL::DEPTH_CLAMP)
      LibGL.enable(LibGL::TEXTURE_2D)
    end
  end
end