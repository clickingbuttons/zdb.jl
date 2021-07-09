module Camera
using GLFW
using LinearAlgebra

mutable struct Cam
  eye::Vector{Float32}
  target::Vector{Float32}
  up::Vector{Float32}
end

main = Cam(
  [1, 1, 1],
  [0, 0, 0],
  [0, 1, 0]
)

last_x = 0.0
last_y = 0.0

function on_click(window, button, action, mods)
  if button == GLFW.MOUSE_BUTTON_2 && action == GLFW.PRESS
    (xoff, yoff) = GLFW.GetCursorPos(window)
    global last_x = xoff
    global last_y = yoff
  end
end

push!(Main.Window.click_callbacks, on_click)

function handleInput(window::GLFW.Window, loop_time::Float64)
  cameraSpeed = Float32(loop_time * 6)
  if GLFW.GetKey(window, GLFW.KEY_W)
    main.eye += normalize(main.target - main.eye) * cameraSpeed
  end
  if GLFW.GetKey(window, GLFW.KEY_S)
    main.eye -= normalize(main.target - main.eye) * cameraSpeed
  end
  if GLFW.GetKey(window, GLFW.KEY_A)
    dir = cross(normalize(main.target - main.eye), main.up) * cameraSpeed
    main.eye -= dir
    main.target -= dir
  end
  if GLFW.GetKey(window, GLFW.KEY_D)
    dir = cross(normalize(main.target - main.eye), main.up) * cameraSpeed
    main.eye += dir
    main.target += dir
  end

  if (!GLFW.GetMouseButton(window, GLFW.MOUSE_BUTTON_2))
    return
  end
  (xoff, yoff) = GLFW.GetCursorPos(window)
  dx = xoff - last_x
  dy = yoff - last_y
  global last_x = xoff
  global last_y = yoff

  mouseSpeed = Float32(loop_time / 4)
  main.target += [dx * mouseSpeed, dy * mouseSpeed, 0f0]
  println(main.target)
end

end
