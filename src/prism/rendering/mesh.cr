require "lib_gl"
require "./vertex"
require "./resource_management/mesh_resource"

module Prism
  class Mesh
    @loaded_models = {} of String => MeshResource
    @resource : MeshResource
    @file_name : String?

    def initialize(file_name : String)
      @file_name = file_name
      if @loaded_models.has_key?(file_name)
        @resource = @loaded_models[file_name]
        @resource.add_reference
      else
        @resource = MeshResource.new
        @loaded_models[file_name] = @resource
      end
      load_mesh(file_name)
    end

    def initialize(verticies : Array(Vertex), indicies : Array(LibGL::Int))
      initialize(verticies, indicies, false)
    end

    def initialize(verticies : Array(Vertex), indicies : Array(LibGL::Int), calc_normals : Bool)
      @resource = MeshResource.new
      add_verticies(verticies, indicies, calc_normals)
    end

    # garbage collection
    def finalize
      # TODO: make sure this is getting called
      puts "cleaning up garbage"
      if @resource.remove_reference && @file_name != nil
        @loaded_models.delete(@file_name)
      end
    end

    private def load_mesh(file_name : String)
      ext = File.extname(file_name)

      unless ext === ".obj"
        puts "Error: File format not supported for mesh data: #{ext}"
        exit 1
      end

      test1 = OBJModel.new(File.join(File.dirname(PROGRAM_NAME), "/res/models/", file_name))
      model = test1.to_indexed_model
      model.calc_normals

      verticies = [] of Vertex
      0.upto(model.positions.size - 1) do |i|
        verticies.push(Vertex.new(model.positions[i], model.tex_coords[i], model.normals[i]))
      end

      add_verticies(verticies, model.indicies, false)
    end

    def add_verticies(verticies : Array(Vertex), indicies : Array(LibGL::Int))
      add_verticies(verticies, indicies, false)
    end

    private def add_verticies(verticies : Array(Vertex), indicies : Array(LibGL::Int), calc_normals : Bool)
      if calc_normals
        calc_normals(verticies, indicies)
      end

      @resource.size = indicies.size

      LibGL.bind_buffer(LibGL::ARRAY_BUFFER, @resource.vbo)
      LibGL.buffer_data(LibGL::ARRAY_BUFFER, verticies.size * Vertex::SIZE * sizeof(Float32), Vertex.flatten(verticies), LibGL::STATIC_DRAW)

      LibGL.bind_buffer(LibGL::ELEMENT_ARRAY_BUFFER, @resource.ibo)
      LibGL.buffer_data(LibGL::ELEMENT_ARRAY_BUFFER, indicies.size * Vertex::SIZE * sizeof(Float32), indicies, LibGL::STATIC_DRAW)
    end

    def draw
      LibGL.enable_vertex_attrib_array(0)
      LibGL.enable_vertex_attrib_array(1)
      LibGL.enable_vertex_attrib_array(2)

      LibGL.bind_buffer(LibGL::ARRAY_BUFFER, @resource.vbo)

      mesh_offset = Pointer(Void).new(0)
      LibGL.vertex_attrib_pointer(0, 3, LibGL::FLOAT, LibGL::FALSE, Vertex::SIZE * sizeof(Float32), mesh_offset)

      texture_offset = Pointer(Void).new(3 * sizeof(Float32)) # TRICKY: skip the three floating point numbers above
      LibGL.vertex_attrib_pointer(1, 2, LibGL::FLOAT, LibGL::FALSE, Vertex::SIZE * sizeof(Float32), texture_offset)

      normals_offset = Pointer(Void).new(5 * sizeof(Float32)) # TRICKY: skip the five floating point numbers above
      LibGL.vertex_attrib_pointer(2, 3, LibGL::FLOAT, LibGL::FALSE, Vertex::SIZE * sizeof(Float32), normals_offset)

      # Draw faces using the index buffer
      LibGL.bind_buffer(LibGL::ELEMENT_ARRAY_BUFFER, @resource.ibo)
      indicies_offset = Pointer(Void).new(0)
      LibGL.draw_elements(LibGL::TRIANGLES, @resource.size, LibGL::UNSIGNED_INT, indicies_offset)

      LibGL.disable_vertex_attrib_array(0)
      LibGL.disable_vertex_attrib_array(1)
      LibGL.disable_vertex_attrib_array(2)
    end

    # Calculates the up direction for all the verticies
    private def calc_normals(verticies : Array(Vertex), indicies : Array(LibGL::Int))
      i = 0
      while i < indicies.size
        i0 = indicies[i]
        i1 = indicies[i + 1]
        i2 = indicies[i + 2]
        v1 = Vector3f.new(verticies[i1].pos - verticies[i0].pos)
        v2 = Vector3f.new(verticies[i2].pos - verticies[i0].pos)

        normal = v1.cross(v2).normalized

        verticies[i0].normal = verticies[i0].normal + normal
        verticies[i1].normal = verticies[i1].normal + normal
        verticies[i2].normal = verticies[i2].normal + normal

        i += 3
      end

      i = 0
      while i < verticies.size
        verticies[i].normal = verticies[i].normal.normalized

        i += 1
      end
    end
  end
end
