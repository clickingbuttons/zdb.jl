using GLFW
using ModernGL
using Logging

include("./window.jl")
include("./gl.jl")

frame = 0
eye = Float32[1, 3, 0]
target = Float32[1.5, 0, 0]
up = Float32[0, 1, 0]

function gl_debug_callback(
  source::GLenum,
  type::GLenum,
  id::GLuint,
  severity::GLenum,
  length::GLsizei,
  message::Ptr{GLchar},
  user_param::Ptr{Cvoid}
)
  if type == GL_DEBUG_TYPE_ERROR
    @error "0x$(string(type, base = 16)): $(unsafe_string(message))"
  else
    @info "0x$(string(type, base = 16)): $(unsafe_string(message))"
  end
end

function main()
  window = Window.create_window()

  gl_debug_callback_ptr = @cfunction(gl_debug_callback, Cvoid, (GLenum, GLenum, GLuint, GLenum, GLsizei, Ptr{GLchar}, Ptr{Cvoid}))
  glEnable(GL_DEBUG_OUTPUT)
  user_param = Ref{Int64}(0)
  glDebugMessageCallback(gl_debug_callback_ptr, user_param)
  shader_program = GL.init_shaders()

  # Cube to draw
  vertices = Float32[
    +0.5f0, +0.5f0, -0.5f0,
    -0.5f0, +0.5f0, -0.5f0,
    +0.5f0, -0.5f0, -0.5f0,
    -0.5f0, -0.5f0, -0.5f0,
    +0.5f0, +0.5f0, +0.5f0,
    -0.5f0, +0.5f0, +0.5f0,
    -0.5f0, -0.5f0, +0.5f0,
    +0.5f0, -0.5f0, +0.5f0,
  ]
  indices = UInt32[
    3, 2, 6, 7, 4, 2, 0,
    3, 1, 6, 5, 4, 1, 0
  ]

  vbo = Ref(GLuint(0))
  vao = Ref(GLuint(0))
  ebo = Ref(GLuint(0))

  glGenVertexArrays(1, vao)
  glBindVertexArray(vao[])

  glGenBuffers(1, vbo)
  glBindBuffer(GL_ARRAY_BUFFER, vbo[])
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)

  glEnableVertexAttribArray(0)
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(Float32), C_NULL)

  glGenBuffers(1, ebo)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo[])
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW)

  uni_world = glGetUniformLocation(shader_program, "gWorld")

  glClearColor(0.2, 0.3, 0.3, 1.0)
  glEnable(GL_DEPTH_TEST)
  glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)

  while !GLFW.WindowShouldClose(window)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

    radius = 1
    camX   = sin(time()) * radius
    camZ   = cos(time()) * radius

    # projection * view * model
    g_world = GL.perspective_project(window) *
      GL.look_at(eye, target, up) * 
      GL.translate(1.5f0, 0f0, 0f0) *
      GL.rotate(Float32(time()), Float32[0, 0, 1]) *
      GL.scale(0.5f0, 0.5f0, 0.5f0)
    glUniformMatrix4fv(uni_world, 1, GL_FALSE, pointer(g_world))
    glDrawElements(GL_TRIANGLE_STRIP, length(indices), GL_UNSIGNED_INT, C_NULL)

    GLFW.PollEvents()
    GLFW.SwapBuffers(window)
    global frame += 1
  end
  GLFW.DestroyWindow(window)
  println(frame, " frames")
end

main()
