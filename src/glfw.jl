using GLFW
using ModernGL
using Logging
using LinearAlgebra
using InteractiveUtils

include("./window.jl")
include("./gl.jl")
include("./camera.jl")
include("./cube.jl")

function renderFrame(window::GLFW.Window, cube_data::Cube.RenderData)
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

  t = time()
  rads = Float32(t % (2 * pi))
  # projection * view * model
  g_world = GL.perspective_project(window) *
    GL.look_at(Camera.main.eye, Camera.main.direction, Camera.main.up) * 
    #GL.translate(0f0, 0f0, 0f0) *
    #GL.rotateX(rads) *
    #GL.rotateY(rads) *
    GL.scale(0.5f0, 0.5f0, 0.5f0)
  Cube.renderFrame(cube_data, g_world)
end

function main()
  window = Window.create_window()
  GL.init_debug()


  glClearColor(0.2, 0.3, 0.3, 1.0)
  glEnable(GL_DEPTH_TEST)
  #glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
  cube_pipeline = Cube.getPipeline()
  println(cube_pipeline)

  frame = 0
  loop_time = 0.0
  loop_time0 = time()
  while !GLFW.WindowShouldClose(window)
    Camera.handleInput(window, loop_time, Camera.main, Camera.state)

    renderFrame(window, cube_pipeline)
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
