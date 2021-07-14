module Cube

using ModernGL
include("./gl.jl")

# Global variables needed for each render
const program = Ref{GLuint}(0)
const ebo = Ref{GLuint}(0)
const vao = Ref{GLuint}(0)
const uni_world = Ref{GLint}(0)

function init_program()
  vertex_shader = glCreateShader(GL_VERTEX_SHADER)
  GL.sourcecompileshader(vertex_shader, """
  #version 330 core
  layout (location = 0) in vec3 Position;
  layout (location = 1) in vec3 inColor;
  layout (location = 2) in mat4 model;
  uniform mat4 gWorld;
  out vec4 Color;
  void main()
  {
    gl_Position = gWorld * model * vec4(Position, 1.0);
    Color = vec4(inColor, 1.0);
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

  global program[] = glCreateProgram()
  glAttachShader(program[], vertex_shader)
  glAttachShader(program[], fragment_shader)
  glLinkProgram(program[])
end

const vertices = Float32[
  +.5, +.5, -.5,
  -.5, +.5, -.5,
  +.5, -.5, -.5,
  -.5, -.5, -.5,
  +.5, +.5, +.5,
  -.5, +.5, +.5,
  -.5, -.5, +.5,
  +.5, -.5, +.5,
]
const indices = UInt32[
  3, 2, 6, 7, 4, 2, 0,
  3, 1, 6, 5, 4, 1, 0
]
const num_cubes = 5

function init_buffers()
  # position
  vbo = Ref{GLuint}(0)
  glGenBuffers(1, vbo)
  glBindBuffer(GL_ARRAY_BUFFER, vbo[])
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)

  glGenVertexArrays(1, vao)
  glBindVertexArray(vao[])
  glEnableVertexAttribArray(0)
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(Float32), C_NULL)

  # color
  cbo = Ref{GLuint}(0)
  glGenBuffers(1, cbo)
  glBindBuffer(GL_ARRAY_BUFFER, cbo[])
  colors = Float32[]
  for i = 1:num_cubes
    append!(colors, Float32[rand(), rand(), rand()])
  end
  glBufferData(GL_ARRAY_BUFFER, sizeof(colors), colors, GL_STATIC_DRAW)
  glEnableVertexAttribArray(1)
  glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(Float32), C_NULL)
  glVertexAttribDivisor(1, 1)

  # model
  mbo = Ref{GLuint}(0)
  glGenBuffers(1, mbo)
  glBindBuffer(GL_ARRAY_BUFFER, mbo[])
  models = Float32[]
  for i = 0:num_cubes-1
    append!(models, GL.translate(Float32(i), 0f0, 0f0) * GL.scale(1f0, Float32(i + 1), 1f0))
  end
  glBufferData(GL_ARRAY_BUFFER, sizeof(models), models, GL_STATIC_DRAW)
  # Mat4s take 4 attribute arrays
  mbo_loc = glGetAttribLocation(program[], "model")
  for i = 0:3
    loc = mbo_loc + i
    glEnableVertexAttribArray(loc)
    offset = Ptr{Cvoid}(4 * i * sizeof(Float32))
    glVertexAttribPointer(loc, 4, GL_FLOAT, GL_FALSE, 4 * 4 * sizeof(Float32), offset)
    glVertexAttribDivisor(loc, 1)
  end

  # indices
  glGenBuffers(1, ebo)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo[])
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW)
end

function init()
  init_program()
  uni_world[] = glGetUniformLocation(program[], "gWorld")
  init_buffers()
end

function renderFrame(g_world::Matrix{Float32})
  glUseProgram(program[])
  glBindVertexArray(vao[])
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo[])
  glUniformMatrix4fv(uni_world[], 1, GL_FALSE, pointer(g_world))
  glDrawElementsInstanced(GL_TRIANGLE_STRIP, length(indices), GL_UNSIGNED_INT, C_NULL, num_cubes)
end

end
