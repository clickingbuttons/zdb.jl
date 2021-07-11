module Axes

using ModernGL
include("./gl.jl")

function getProgram()::GLuint
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

  shader_program = glCreateProgram()
  glAttachShader(shader_program, vertex_shader)
  glAttachShader(shader_program, fragment_shader)
  glLinkProgram(shader_program)

  shader_program
end

function getVbo()::NamedTuple{(:vbo, :vao, :num_arrays), Tuple{GLuint, GLuint, GLsizei}}
  vertices = Float32[
    # pos     ,  color
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

  vbo = Ref(GLuint(0))
  vao = Ref(GLuint(0))

  glGenVertexArrays(1, vao)
  glBindVertexArray(vao[])

  glGenBuffers(1, vbo)
  glBindBuffer(GL_ARRAY_BUFFER, vbo[])
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)

  glEnableVertexAttribArray(0)
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(Float32), C_NULL)
  glEnableVertexAttribArray(1)
  stride = Ptr{Cvoid}(3 * sizeof(Float32))
  glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(Float32), stride)


  (vbo=vbo[], vao=vao[], num_arrays=length(vertices) / 6)
end

# Global variables needed for each render
const shader_program = Ref{GLuint}(0)
const vbo = Ref{GLuint}(0)
const vao = Ref{GLuint}(0)
const uni_world = Ref{GLint}(0)
const num_arrays = Ref{GLsizei}(0)

function init()
  shader_program[] = getProgram()
  uni_world[] = glGetUniformLocation(shader_program[], "gWorld")
  (vbo[], vao[], num_arrays[]) = getVbo()
end

function renderFrame(g_world::Matrix{Float32})
  glUseProgram(shader_program[])
  glBindVertexArray(vao[])
  glBindBuffer(GL_ARRAY_BUFFER, vbo[])
  glUniformMatrix4fv(uni_world[], 1, GL_FALSE, pointer(g_world))
  glDrawArrays(GL_LINES, 0, num_arrays[])
end

end
