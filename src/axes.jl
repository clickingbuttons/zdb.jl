module Axes

using ModernGL
include("./gl.jl")

# Global variables needed for each render
const program = Ref{GLuint}(0)
const vao = Ref{GLuint}(0)
const vbo = Ref{GLuint}(0)
const uni_world = Ref{GLint}(0)

function init_program()
  vertex_shader = glCreateShader(GL_VERTEX_SHADER)
  GL.sourcecompileshader(vertex_shader, """
  #version 330 core
  layout (location = 0) in vec3 Position;
  layout (location = 1) in vec3 inColor;
  uniform mat4 gWorld;
  out vec4 Color;
  void main()
  {
    gl_Position = gWorld * vec4(Position, 1.0);
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
  # pos      ,  color
  # x
  -10,  0,  0,  1, 0, 0,
   10,  0,  0,  1, 0, 0,
  # y
   0, -10,  0,  0, 1, 0,
   0,  10,  0,  0, 1, 0,
  # z
   0,  0, -10,  0, 0, 1,
   0,  0,  10,  0, 0, 1,
]
function init_buffers()
  glGenBuffers(1, vbo)
  glBindBuffer(GL_ARRAY_BUFFER, vbo[])
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)

  glGenVertexArrays(1, vao)
  glBindVertexArray(vao[])
  glEnableVertexAttribArray(0)
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(Float32), C_NULL)
  glEnableVertexAttribArray(1)
  offset = Ptr{Cvoid}(3 * sizeof(Float32))
  glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(Float32), offset)
end

function init()
  init_program()
  uni_world[] = glGetUniformLocation(program[], "gWorld")
  init_buffers()
end

function renderFrame(g_world::Matrix{Float32})
  glUseProgram(program[])
  glBindVertexArray(vao[])
  glBindBuffer(GL_ARRAY_BUFFER, vbo[])
  glUniformMatrix4fv(uni_world[], 1, GL_FALSE, pointer(g_world))
  glDrawArrays(GL_LINES, 0, length(vertices))
end

end
