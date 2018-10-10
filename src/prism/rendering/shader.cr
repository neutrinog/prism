require "lib_gl"
require "../core/vector3f"
require "../core/matrix4f"
require "./material"
require "../core/transform"
require "./rendering_engine_protocol"

module Prism

  class Shader

    @program : LibGL::UInt
    @uniforms : Hash(String, Int32)

    def initialize
      @program = LibGL.create_program()
      @uniforms = {} of String => Int32

      if @program == 0
        program_error_code = LibGL.get_error()
        puts "Error #{program_error_code}: Shader creation failed. Could not find valid memory location in constructor"
        exit 1
      end
    end

    # TODO: make this private again
    def load_shader(file_name : String) : String

      include_directive = "#include"

      path = File.join(File.dirname(PROGRAM_NAME), "/res/shaders/", file_name)
      shader_source = ""

      # glsl dependencies can be added like: #include "file.sh"
      File.each_line(path) do |line|
        include_match = line.scan(/\#include\s+["<]([^">]*)[>"]/)
        if include_match.size > 0
          shader_source += self.load_shader(include_match[0][1])
        else
          shader_source += line + "\n"
        end
      end

      return shader_source
    end

    # uses the shader
    def bind
      LibGL.use_program(@program)
    end

    def update_uniforms(transform : Transform, material : Material, rendering_engine : RenderingEngineProtocol)
    end

    def add_vertex_shader_from_file(file : String)
      add_program(load_shader(file), LibGL::VERTEX_SHADER)
    end

    def add_geometry_shader_from_file(file : String)
        add_program(load_shader(file), LibGL::GEOMETRY_SHADER)
    end

    def add_fragment_shader_from_file(file : String)
        add_program(load_shader(file), LibGL::FRAGMENT_SHADER)
    end

    def add_vertex_shader(text : String)
      add_program(text, LibGL::VERTEX_SHADER)
    end

    def add_geometry_shader(text : String)
        add_program(text, LibGL::GEOMETRY_SHADER)
    end

    def add_fragment_shader(text : String)
        add_program(text, LibGL::FRAGMENT_SHADER)
    end

    # Parses the shader text for attribute delcarations and automatically adds them
    def add_all_attributes(shader_text : String)
      keyword = "attribute"
      start_location = shader_text.index(keyword)
      attribute_number = 0
      while start = start_location
        end_location = shader_text.index(";", start).not_nil!
        uniform_line = shader_text[start..end_location]
        matches = uniform_line.scan(/#{keyword}\s+([a-zA-Z0-9]+)\s+([a-zA-Z0-9]+)/)
        attribute_type = matches[0][1]
        attribute_name = matches[0][2]

        set_attrib_location(attribute_name, attribute_number)
        attribute_number += 1

        start_location = shader_text.index(keyword, end_location)
      end
    end

    # Parses the shader text for uniform declarations and automatically adds them
    def add_all_uniforms(shader_text : String)
      keyword = "uniform"
      start_location = shader_text.index(keyword)
      while start = start_location
        end_location = shader_text.index(";", start).not_nil!
        uniform_line = shader_text[start..end_location]
        matches = uniform_line.scan(/#{keyword}\s+([a-zA-Z0-9]+)\s+([a-zA-Z0-9]+)/)
        uniform_type = matches[0][1]
        uniform_name = matches[0][2]

        add_uniform(uniform_name)

        start_location = shader_text.index(keyword, end_location)
      end
    end

    # Adds a uniform variable for the shader to keep track of
    # The shader must be compiled before adding uniforms.
    def add_uniform( uniform : String)
      uniform_location = LibGL.get_uniform_location(@program, uniform);

      if uniform_location == -1
        uniform_error_code = LibGL.get_error()
        puts "Error #{uniform_error_code}: Could not find location for uniform '#{uniform}'."
        exit 1
      end

      @uniforms[uniform] = uniform_location
    end

    # Sets an integer uniform variable value
    def set_uniform( name : String, value : LibGL::Int)
      LibGL.uniform_1i(@uniforms[name], value)
    end

    # Sets a float uniform variable value
    def set_uniform( name : String, value : LibGL::Float)
      LibGL.uniform_1f(@uniforms[name], value)
    end

    # Sets a 3 dimensional float vector value to a uniform variable
    def set_uniform( name : String, value : Vector3f)
      LibGL.uniform_3f(@uniforms[name], value.x, value.y, value.z)
    end

    # Sets a 4 dimensional matrix float value to a uniform variable
    def set_uniform( name : String, value : Matrix4f)
      LibGL.uniform_matrix_4fv(@uniforms[name], 1, LibGL::TRUE, value.as_array)
    end

    def set_attrib_location(attribute : String, location : LibGL::Int)
      LibGL.bind_attrib_location(@program, location, attribute)
    end

    # compiles the shader
    def compile
      LibGL.link_program(@program)

      LibGL.get_program_iv(@program, LibGL::LINK_STATUS, out link_status)
      if link_status == LibGL::FALSE
        LibGL.get_program_info_log(@program, 1024, nil, out link_log)
        link_log_str = String.new(pointerof(link_log))
        link_error_code = LibGL.get_error()
        puts "Error #{link_error_code}: Failed linking shader program: #{link_log_str}"
        exit 1
      end

      LibGL.validate_program(@program)

      LibGL.get_program_iv(@program, LibGL::VALIDATE_STATUS, out validate_status)
      if validate_status == LibGL::FALSE
        LibGL.get_program_info_log(@program, 1024, nil, out validate_log)
        validate_log_str = String.new(pointerof(validate_log))
        validate_error_code = LibGL.get_error()
        puts "Error #{validate_error_code}: Failed validating shader program: #{validate_log_str}"
        exit 1
      end

      # TODO: delete the shaders since they are linked into the program and we no longer need them
      # LibGL.delete_shader(shader)
    end

    private def add_program(text : String, type : LibGL::UInt)
      shader = LibGL.create_shader(type)
      if shader == 0
        shader_error_code = LibGL.get_error()
        puts "Error #{shader_error_code}: Shader creation failed. Could not find valid memory location when adding shader"
        exit 1
      end

      ptr = text.to_unsafe
      source = [ptr]
      size = [text.size]
      size = Pointer(Int32).new(0)
      LibGL.shader_source(shader, 1, source, size)
      LibGL.compile_shader(shader)

      LibGL.get_shader_iv(shader, LibGL::COMPILE_STATUS, out compile_status)
      if compile_status == LibGL::FALSE
        LibGL.get_shader_info_log(shader, 1024, nil, out compile_log)
        compile_log_str = String.new(pointerof(compile_log))
        compile_error_code = LibGL.get_error()
        puts "Error #{compile_error_code}: Failed compiling shader '#{text}': #{compile_log_str}"
        exit 1
      end

      LibGL.attach_shader(@program, shader)
    end

  end

end
