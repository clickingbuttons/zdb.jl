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

function init_shaders()::UInt32
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

function rotate(degs::Float32, normal::Vector{Float32})::Matrix{Float32}
  sin_a = Float32(sin(time()))
  cos_a = Float32(cos(time()))
  [
    cos_a 0f0 -sin_a 0f0;
    0f0 1f0 0f0 0f0;
    sin_a 0f0 cos_a 0f0;
    0f0 0f0 0f0 1f0;
  ]
end

function translate(x::Float32, y::Float32, z::Float32)::Matrix{Float32}
  res = [
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

  res = [
    f/ar 0f0 0f0 0f0;
    0f0   f  0f0 0f0;
    0f0  0f0  A   B ;
    0f0  0f0 1f0 0f0;
  ]

  #res = Matrix{Float32}(I, 4, 4)
  res
end

function look_at(eye::Vector{Float32}, center::Vector{Float32}, up::Vector{Float32})::Matrix{Float32}
  f = normalize(center - eye)
  u = normalize(up)
  s = normalize(cross(f, u))
  u = cross(s, f)

  [
    s[1] u[1] -f[1] 0;
    s[2] u[2] -f[2] 0;
    s[3] u[3] -f[3] 0;
    -dot(s, eye) -dot(u, eye) -dot(f, eye) 1;
  ]
end

end

