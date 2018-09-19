require "lib_gl"

module Prism

  class Texture

    getter id

    def initialize(file_name : String)
      initialize(load_texture(file_name))
    end

    def initialize(@id : LibGL::UInt)
    end

    def bind
      LibGL.bind_texture(LibGL::TEXTURE_2D, id);
    end

    private def load_texture(file_name : String) : LibGL::UInt
      ext = File.extname(file_name)

      # read texture data
      path = File.join(File.dirname(PROGRAM_NAME), "/res/textures/", file_name)
      data = LibTools.load_png(path, out width, out height, out num_channels)

      # create texture
      LibGL.gen_textures(1, out id)
      LibGL.bind_texture(LibGL::TEXTURE_2D, id)

      # set the texture wrapping/filtering options
      LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_WRAP_S, LibGL::REPEAT)
      LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_WRAP_T, LibGL::REPEAT)
      LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MIN_FILTER, LibGL::LINEAR)
      LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MAG_FILTER, LibGL::LINEAR)

      if data
        LibGL.tex_image_2d(LibGL::TEXTURE_2D, 0, LibGL::RGB, width, height, 0, LibGL::RGB, LibGL::UNSIGNED_BYTE, data)
        LibGL.generate_mipmap(LibGL::TEXTURE_2D)
        # TODO: free image data from stbi. see LibTools.
      else
        puts "Error: Failed to load texture data from #{path}"
        exit 1
      end
      return id
    end

  end

end