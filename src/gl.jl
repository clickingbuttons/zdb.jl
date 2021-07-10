module GL

using GLFW
using ModernGL
using LinearAlgebra

function sourcecompileshader(shaderID::GLuint, shadercode::String)::Nothing
  shadercode = Vector{UInt8}(shadercode)
  shader_code_ptrs = Ptr{UInt8}[pointer(shadercode)]
  len = Ref{GLint}(length(shadercode))
  glShaderSource(shaderID, 1, shader_code_ptrs, len)
  glCompileShader(shaderID)
end

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

function init_debug()
  gl_debug_callback_ptr = @cfunction(gl_debug_callback, Cvoid, (GLenum, GLenum, GLuint, GLenum, GLsizei, Ptr{GLchar}, Ptr{Cvoid}))
  glEnable(GL_DEBUG_OUTPUT)
  user_param = Ref{Int64}(0)
  glDebugMessageCallback(gl_debug_callback_ptr, user_param)
end

# https://eater.net/quaternions/video/intro
# quat1 = Float32[1, 1, 0]
# quat1 /= norm(quat1)
# rotation1 = quat1 * Float32(sin(t))
# push!(rotation1, cos(t))
function rotate(quat::Vector{Float32})::Matrix{Float32}
  yy2 = 2f0 * quat[2]^2
  xy2 = 2f0 * quat[1] * quat[2]
  xz2 = 2f0 * quat[1] * quat[3]
  yz2 = 2f0 * quat[2] * quat[3]
  zz2 = 2f0 * quat[3]^2 
  wz2 = 2f0 * quat[4] * quat[3]
  wy2 = 2f0 * quat[4] * quat[2]
  wx2 = 2f0 * quat[4] * quat[1]
  xx2 = 2f0 * quat[1]^2
  Float32[
    1-yy2-zz2  xy2+wz2   xz2-wy2  0;
     xy2-wz2  1-xx2-zz2  yz2+wx2  0;
     xz2+wy2   yz2-wx2  1-xx2-yy2 0;
        0         0         0     1;
  ]
end

function rotateX(rads::Float32)::Matrix{Float32}
  c = cos(rads)
  s = sin(rads)
  [
    1 0  0 0;
    0 c -s 0;
    0 s  c 0;
    0 0  0 1;
  ]
end

function rotateY(rads::Float32)::Matrix{Float32}
  c = cos(rads)
  s = sin(rads)
  Float32[
     c  0 s 0;
     0  1 0 0;
    -s  0 c 0;
     0  0 0 1;
  ]
end

function rotateZ(rads::Float32)::Matrix{Float32}
  c = cos(rads)
  s = sin(rads)
  Float32[
    c -s 0 0;
    s  c 0 0;
    0  0 1 0;
    0  0 0 1;
  ]
end

function translate(x::Float32, y::Float32, z::Float32)::Matrix{Float32}
  Float32[
    1 0 0 x;
    0 1 0 y;
    0 0 1 z;
    0 0 0 1;
  ]
end

function scale(x::Float32, y::Float32, z::Float32)::Matrix{Float32}
  Float32[
    x 0 0 0;
    0 y 0 0;
    0 0 z 0;
    0 0 0 1;
  ]
end

function perspective_project(window::GLFW.Window)::Matrix{Float32}
  size = GLFW.GetWindowSize(window)
  ar = Float32(size.width / size.height)
  z_near = 0.1f0
  z_far = 1000f0
  z_range = z_near - z_far
  tanFOV = tan(deg2rad(45f0 / 2.0))
  f = 1f0 / tanFOV

  A = (-z_far - z_near) / z_range
  B = 2f0 * z_far * z_near / z_range

  Float32[
    f/ar 0 0 0;
     0   f 0 0;
     0   0 A B;
     0   0 1 0;
  ]
end

function look_at(eye::Vector{Float32}, direction::Vector{Float32}, up::Vector{Float32})::Matrix{Float32}
  z = normalize(direction)
  x = normalize(cross(up, z))
  y = cross(z, x)

  Float32[
    x[1] x[2] x[3] dot(x, eye);
    y[1] y[2] y[3] dot(y, eye);
    z[1] z[2] z[3] dot(z, eye);
     0    0    0        1     ;
  ]
end

#=
function look_at_fps(eye::Vector{Float32}, pitch::Float32, yaw::Float32)::Matrix{Float32}
  sp = sin(pitch)
  cp = cos(pitch)
  sy = sin(yaw)
  cy = cos(yaw)

  x = Float32[cy, 0, -sy]
  y = Float32[sy*sp, cp, cy*sp]
  z = Float32[sy*cp, -sp, cp*cy]

  Float32[
    x[1] y[1] z[1] 0;
    x[2] y[2] z[2] 0;
    x[3] y[3] z[3] 0;
    -dot(x, eye) -dot(y, eye) -dot(z, eye) 1;
  ]
end
=#

end

