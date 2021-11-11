module Axes

using LinearAlgebra
using GLFW
using ModernGL
using ..GL
using ..Camera

# Global variables needed for each render
const program = Ref{GLuint}(0)
const vao = Ref{GLuint}(0)
const vbo = Ref{GLuint}(0)
const uni_world = Ref{GLint}(0)

mutable struct XYSelect
  start::Union{GL.Vec2, Nothing}
  stop::Union{GL.Vec2, Nothing}
end
xyselection = XYSelect(nothing, nothing)
function reset_xyselection()
  xyselection.start = nothing
  xyselection.stop = nothing
end

function init_program()
  vertex_shader = glCreateShader(GL_VERTEX_SHADER)
  GL.sourcecompileshader(vertex_shader, """
  #version 330 core
  layout (location = 0) in vec3 Position;
  layout (location = 1) in vec3 inColor;
  uniform mat4 gWorld;
  out vec4 Color;
  void main()
  {
    gl_Position = gWorld * vec4(Position, 1.0);
    Color = vec4(inColor, 1.0);
  }
  """)

  fragment_shader = glCreateShader(GL_FRAGMENT_SHADER)
  GL.sourcecompileshader(fragment_shader, """
  #version 330 core
  in vec4 Color;
  out vec4 outColor;
  void main()
  {
    outColor = Color;
  }   
  """)

  global program[] = glCreateProgram()
  glAttachShader(program[], vertex_shader)
  glAttachShader(program[], fragment_shader)
  glLinkProgram(program[])
end

vertices = Float32[]
x = 10f0
y = 10f0
z = 10f0

function get_selection_vertices()
  min_x = xyselection.start != nothing ? min(xyselection.start.x, xyselection.stop.x) : 0
  min_y = xyselection.start != nothing ? min(xyselection.start.y, xyselection.stop.y) : 0
  max_x = xyselection.start != nothing ? max(xyselection.start.x, xyselection.stop.x) : 0
  max_y = xyselection.start != nothing ? max(xyselection.start.y, xyselection.stop.y) : 0

  Float32[
    min_x, -min_y, 0.001,   0, 0, 1,
    min_x, -max_y, 0.001,   0, 0, 1,
    min_x, -max_y, 0.001,   0, 0, 1,
    max_x, -max_y, 0.001,   0, 0, 1,
    max_x, -max_y, 0.001,   0, 0, 1,
    max_x, -min_y, 0.001,   0, 0, 1,
    max_x, -min_y, 0.001,   0, 0, 1,
    min_x, -min_y, 0.001,   0, 0, 1,
  ]
end

function init_buffers(window::GLFW.Window)
  (width, height) = GLFW.GetWindowSize(window)
  ratio = width / height
  global x *= ratio
  global vertices = vcat(
    Float32[
      # pos  ,  color
      # x
      0,  0, 0,  1, 0, 0,
      x,  0, 0,  1, 0, 0,
      # y
      0,  0, 0,  0, 1, 0,
      0, -y, 0,  0, 1, 0,
      # z
      0,  0, 0,  0, 0, 1,
      0,  0, z,  0, 0, 1,
    ],
    # selection
    get_selection_vertices()
  )
  glGenBuffers(1, vbo)
  glBindBuffer(GL_ARRAY_BUFFER, vbo[])
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)

  glGenVertexArrays(1, vao)
  glBindVertexArray(vao[])
  glEnableVertexAttribArray(0)
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(Float32), C_NULL)
  glEnableVertexAttribArray(1)
  offset = Ptr{Cvoid}(3 * sizeof(Float32))
  glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(Float32), offset)
end

function init(window::GLFW.Window)
  init_program()
  uni_world[] = glGetUniformLocation(program[], "gWorld")
  init_buffers(window)
end

function renderFrame(g_world::Matrix{Float32})
  glUseProgram(program[])
  glBindVertexArray(vao[])
  glBindBuffer(GL_ARRAY_BUFFER, vbo[])
  glBufferSubData(GL_ARRAY_BUFFER, 6 * 6 * sizeof(Float32), 8 * 6 * sizeof(Float32), get_selection_vertices())
  glUniformMatrix4fv(uni_world[], 1, GL_FALSE, pointer(g_world))
  glDrawArrays(GL_LINES, 0, length(vertices))
end

function lineplanecollision(
  planenorm::Vector{Float32},
  planepnt::Vector{Float32},
  raydir::Vector{Float32},
  raypnt::Vector{Float32}
)::Vector{Float32}
  ndotu = dot(planenorm, raydir)
  if ndotu ≈ 0 Float32[] end

  w  = raypnt - planepnt
  si = -dot(planenorm, w) / ndotu
  ψ  = w .+ si .* raydir .+ planepnt
  return ψ
end

function worldcoordsxy(window::GLFW.Window)::Vector{Float32}
  # https://antongerdelan.net/opengl/raycasting.html
  # Step 0: 2d Viewport Coordinates
  (xoff, yoff) = GLFW.GetCursorPos(window)
  (width, height) = GLFW.GetWindowSize(window)
  # Step 1: 3d Normalised Device Coordinates
  x = (2.0 * xoff) / width - 1.0
  y = 1.0 - (2.0 * yoff) / height
  # Step 2: 4d Homogeneous Clip Coordinates
  ray_clip = Float32[x, y, -1.0, 1.0]
  # Step 3: 4d Eye (Camera) Coordinates
  projection_matrix = GL.perspective_project(window)
  ray_eye = inv(projection_matrix) * ray_clip
  ray_eye[3] = 1.0
  ray_eye[4] = 0.0
  # Step 4: 4d World Coordinates
  view_matrix = GL.look_at(Camera.main.eye, Camera.main.direction, Camera.main.up)
  ray_world = inv(view_matrix) * ray_eye
  ray_world = ray_world[1:3]

  # Map coords to point on xy plane
  xy_point = lineplanecollision(Float32[0, 0, 1], Float32[0, 0, 0], ray_world, Camera.main.eye)
  xy_point[1] *= -1

  xy_point
end

function click_callback(window::GLFW.Window, button::GLFW.MouseButton, action::GLFW.Action, mods::Int32)
  if button == GLFW.MOUSE_BUTTON_1
    if xyselection.start != nothing && xyselection.stop != nothing
      reset_xyselection()
    end
    xy_point = worldcoordsxy(window)
    if length(xy_point) > 0
      xy_point = GL.Vec2(xy_point)
      if xyselection.start == nothing && action == GLFW.PRESS
        xyselection.start = xy_point
      elseif action == GLFW.RELEASE
        xyselection.stop = xy_point
      end
    else
      reset_xyselection()
    end
  end
end

function handleInput(window::GLFW.Window, loop_time::Float64)
  if xyselection.start != nothing && GLFW.GetMouseButton(window, GLFW.MOUSE_BUTTON_1)
    xy_point = worldcoordsxy(window)
    if length(xy_point) > 0
      xyselection.stop = GL.Vec2(xy_point)
    end
  end
end

end
