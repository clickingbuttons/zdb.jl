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
  [-3.4438117, -1.6785045, -9.841953],
  [0.020469321, -0.45189014, -0.8918387],
  [0.0, 0.0, 1.0],
  -1.1013938f0,
  -9.470044f0
)

mutable struct GlobalCamState
  mouse2_down::Bool
  last_x::Float64
  last_y::Float64
end

state = GlobalCamState(
  false,
  0.0,
  0.0
)

function handleInput(window::GLFW.Window, loop_time::Float64, cam::Cam, state::GlobalCamState)
  mouse2_down_check = GLFW.GetMouseButton(window, GLFW.MOUSE_BUTTON_2)

  cameraSpeed = Float32(loop_time * 3)
  if GLFW.GetKey(window, GLFW.KEY_W)
    if mouse2_down_check
      cam.eye -= cam.direction * cameraSpeed
    else
      cam.eye -= cam.up * cameraSpeed
    end
  end
  if GLFW.GetKey(window, GLFW.KEY_S)
    cam.eye += cam.direction * cameraSpeed
  end
  if GLFW.GetKey(window, GLFW.KEY_A)
    cam.eye -= cross(cam.direction, cam.up) * cameraSpeed * 2
  end
  if GLFW.GetKey(window, GLFW.KEY_D)
    cam.eye += cross(cam.direction, cam.up) * cameraSpeed * 2
  end
  if GLFW.GetKey(window, GLFW.KEY_SPACE)
    cam.eye -= cam.up * cameraSpeed
  end

  (xoff, yoff) = GLFW.GetCursorPos(window)
  dx = xoff - state.last_x
  dy = yoff - state.last_y
  state.last_x = xoff
  state.last_y = yoff
  if !state.mouse2_down && mouse2_down_check
    state.mouse2_down = true
    GLFW.SetInputMode(window, GLFW.CURSOR, GLFW.CURSOR_DISABLED)
    return
  elseif state.mouse2_down && !mouse2_down_check
    state.mouse2_down = false
    GLFW.SetInputMode(window, GLFW.CURSOR, GLFW.CURSOR_NORMAL)
  end
  if !state.mouse2_down
    return
  end

  mouseSpeed = Float32(loop_time / 4)
  cam.pitch += (dy * mouseSpeed) % (2*pi)
  cam.yaw   += (dx * mouseSpeed) % (2*pi)
  
  if cam.pitch > pi/2 - 0.1
    cam.pitch = pi/2 - 0.1
  elseif cam.pitch < 0.1 - pi/2
    cam.pitch = 0.1 - pi/2
  end

  cam.direction = normalize(Float32[
    sin(cam.yaw) * cos(cam.pitch),
    cos(cam.yaw) * cos(cam.pitch),
    sin(cam.pitch),
  ])
end

end
