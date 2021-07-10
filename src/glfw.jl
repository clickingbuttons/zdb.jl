using GLFW
using ModernGL
using Logging
using LinearAlgebra
using InteractiveUtils

include("./window.jl")
include("./gl.jl")
include("./camera.jl")

function renderFrame(indices::Vector{UInt32}, window::GLFW.Window, uni_world::Int32)
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

  t = time()
  rads = Float32(t % (2 * pi))
  # projection * view * model
  g_world = GL.perspective_project(window) *
    GL.look_at(Camera.main.eye, Camera.main.direction, Camera.main.up) * 
    #GL.translate(0f0, 0f0, 0f0) *
    GL.rotateX(rads) *
    GL.rotateY(rads) *
    GL.scale(0.5f0, 0.5f0, 0.5f0)
  glUniformMatrix4fv(uni_world, 1, GL_FALSE, pointer(g_world))
  glDrawElements(GL_TRIANGLE_STRIP, length(indices), GL_UNSIGNED_INT, C_NULL)
end

function main()
  window = Window.create_window()
  GL.init_debug()
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
  #glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)

  frame = 0
  loop_time = 0.0
  quat1 = normalize(Float32[1, 1, 0])
  quat2 = normalize(Float32[0, 1, 1])
  loop_time0 = time()

  #@code_warntype Camera.handleInput(window, loop_time, Camera.main, Camera.state)
  while !GLFW.WindowShouldClose(window)
    Camera.handleInput(window, loop_time, Camera.main, Camera.state)

    renderFrame(indices, window, uni_world)
    GLFW.SwapBuffers(window)
    GLFW.PollEvents()

    frame += 1
    t = time()
    loop_time = t - loop_time0
    loop_time0 = t
  end
  GLFW.DestroyWindow(window)
  println(frame, " frames")
end

main()
