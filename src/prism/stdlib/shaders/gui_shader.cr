module Prism
  # A generic shader for the GUI
  class GUIShader < Prism::DefaultShader
    uniform "guiTexture", Prism::Texture2D
    uniform "transformationMatrix", Matrix4f

    def initialize
      super("gui")
    end
  end
end
