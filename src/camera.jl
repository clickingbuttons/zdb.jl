module Camera
using GLFW
using LinearAlgebra

# https://www.3dgep.com/understanding-the-view-matrix/#fps-camera
mutable struct Cam
  eye::Vector{Float32}
  direction::Vector{Float32}
  up::Vector{Float32}
  pitch::Float32
  yaw::Float32
end

main = Cam(
  [1, 0, 0],
  [1, 0, 0],
  [0, 1, 0],
  0f0,
  0f0
)

mouse2_down = false
last_x = 0.0
last_y = 0.0

function handleInput(window::GLFW.Window, loop_time::Float64)
  cameraSpeed = Float32(loop_time * 3)
  if GLFW.GetKey(window, GLFW.KEY_W)
    main.eye -= main.direction * cameraSpeed
  end
  if GLFW.GetKey(window, GLFW.KEY_S)
    main.eye += main.direction * cameraSpeed
  end
  if GLFW.GetKey(window, GLFW.KEY_A)
    main.eye -= cross(main.direction, main.up) * cameraSpeed
  end
  if GLFW.GetKey(window, GLFW.KEY_D)
    main.eye += cross(main.direction, main.up) * cameraSpeed
  end

  (xoff, yoff) = GLFW.GetCursorPos(window)
  dx = xoff - last_x
  dy = yoff - last_y
  global last_x = xoff
  global last_y = yoff
  mouse2_down_check = GLFW.GetMouseButton(window, GLFW.MOUSE_BUTTON_2)
  if !mouse2_down && mouse2_down_check
    global mouse2_down = true
    GLFW.SetInputMode(window, GLFW.CURSOR, GLFW.CURSOR_DISABLED)
    return
  elseif mouse2_down && !mouse2_down_check
    global mouse2_down = false
    GLFW.SetInputMode(window, GLFW.CURSOR, GLFW.CURSOR_NORMAL)
  end
  if !mouse2_down
    return
  end
  println("$dx $dy")

  mouseSpeed = Float32(loop_time / 4)
  main.pitch += (dy * mouseSpeed) % (2*pi)
  main.yaw   += (dx * mouseSpeed) % (2*pi)
  
  if main.pitch > pi/2 - 0.1
    main.pitch = pi/2 - 0.1
  elseif main.pitch < 0.1 - pi/2
    main.pitch = 0.1 - pi/2
  end

  main.direction = normalize(Float32[
    cos(main.yaw) * cos(main.pitch),
    sin(main.pitch),
    sin(main.yaw) * cos(main.pitch)
  ])
end

end
