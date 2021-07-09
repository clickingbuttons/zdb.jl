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

function init_shaders()::UInt32
  init_debug()
  vertex_shader = glCreateShader(GL_VERTEX_SHADER)
  GL.sourcecompileshader(vertex_shader, """
  #version 330 core
  layout (location = 0) in vec3 Position;
  uniform mat4 gWorld;
  out vec4 Color;
  void main()
  {
    gl_Position = gWorld * vec4(Position, 1.0);
    Color = vec4(clamp(Position, 0.0, 1.0), 1.0);
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

  shader_program = glCreateProgram()
  glAttachShader(shader_program, vertex_shader)
  glAttachShader(shader_program, fragment_shader)
  glLinkProgram(shader_program)
  glUseProgram(shader_program)

  shader_program
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
  [
    1-yy2-zz2  xy2+wz2   xz2-wy2  0f0;
     xy2-wz2  1-xx2-zz2  yz2+wx2  0f0;
     xz2+wy2   yz2-wx2  1-xx2-yy2 0f0;
       0f0       0f0      0f0     1f0;
  ]
end

function rotateX(rads::Float32)::Matrix{Float32}
  c = cos(rads)
  s = sin(rads)
  [
    1f0 0f0 0f0 0f0
    0f0  c  -s  0f0
    0f0  s   c  0f0
    0f0 0f0 0f0 1f0
  ]
end

function rotateY(rads::Float32)::Matrix{Float32}
  c = cos(rads)
  s = sin(rads)
  [
     c  0f0  s  0f0
    0f0 1f0 0f0 0f0
    -s  0f0  c  0f0
    0f0 0f0 0f0 1f0
  ]
end

function rotateZ(rads::Float32)::Matrix{Float32}
  c = cos(rads)
  s = sin(rads)
  [
     c  -s  0f0 0f0
     s   c  0f0 0f0
    0f0 0f0 1f0 0f0
    0f0 0f0 0f0 1f0
  ]
end

function translate(x::Float32, y::Float32, z::Float32)::Matrix{Float32}
  [
    1f0 0f0 0f0 x;
    0f0 1f0 0f0 y;
    0f0 0f0 1f0 z;
    0f0 0f0 0f0 1f0;
  ]
end

function scale(x::Float32, y::Float32, z::Float32)::Matrix{Float32}
  [
     x  0f0 0f0 0f0
    0f0  y  0f0 0f0
    0f0 0f0  z  0f0
    0f0 0f0 0f0 1f0
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

  [
    f/ar 0f0 0f0 0f0;
    0f0   f  0f0 0f0;
    0f0  0f0  A   B ;
    0f0  0f0 1f0 0f0;
  ]
end

function look_at(eye::Vector{Float32}, center::Vector{Float32}, up::Vector{Float32})::Matrix{Float32}
  f = normalize(center - eye)
  u = normalize(up)
  s = normalize(cross(f, u))
  u = cross(s, f)

  [
     s[1]  s[2]   s[3] -dot(s, eye);
     u[1]  u[2]   u[3] -dot(u, eye);
    -f[1] -f[2]  -f[3] -dot(f, eye);
      0     0      0        1;
  ]
end

end

