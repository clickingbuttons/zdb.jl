using GLFW
using ModernGL
using Logging
using LinearAlgebra
using InteractiveUtils

include("./window.jl")
using .Window
include("./gl.jl")
using .GL
include("./camera.jl")
using .Camera
include("./axes.jl")
using .Axes
include("./scan.jl")
include("./zdb.jl")
include("./aggs.jl")
using .Aggs
include("./cube.jl")
using .Cube

function renderFrame(window::GLFW.Window)
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

  t = time()
  rads = Float32(t % (2 * pi))
  # projection * view * model
  g_world = GL.perspective_project(window) *
    GL.look_at(Camera.main.eye, Camera.main.direction, Camera.main.up)
  Axes.renderFrame(g_world)
  Cube.renderFrame(g_world)
end

function main()
  push!(Window.key_callbacks, Camera.key_callback)
  push!(Window.key_callbacks, Cube.key_callback)
  window = Window.createWindow()
  GL.initDebug()
  Axes.init(window)
  Cube.init(window)
  Cube.loadDate("2004-01-02")
  Cube.loadSymbol("SPY")

  glClearColor(0.2, 0.3, 0.3, 1.0)
  glEnable(GL_DEPTH_TEST)
  #glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)

  frame = 0
  loop_time = 0.0
  loop_time0 = time()
  while !GLFW.WindowShouldClose(window)
    Camera.handleInput(window, loop_time, Camera.main)

    renderFrame(window)
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
