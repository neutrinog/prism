module Prism
  class TexturePack
    @textures : Hash(String, Prism::Texture)

    getter textures

    # Creates an empty texture pack
    def initialize
      @textures = {} of String => Prism::Texture
    end

    # Adds a *texture* to the pack.
    # The *name* that should match the name of a sampler uniform in the shader program
    def add(name : String, texture : Prism::Texture)
      @textures[name] = texture
    end

    # Removes a named texture from the pack
    def delete(name : String)
      if @textures.has_key? name
        @textures.delete name1
      end
    end
  end
end