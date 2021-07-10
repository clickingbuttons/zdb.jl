module Cube

using ModernGL
include("./gl.jl")

function getProgram()::GLuint
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

  shader_program
end

function getEbo()::NamedTuple{(:ebo, :num_indices), Tuple{GLuint, GLsizei}}
  vertices = Float32[
    +.5, +.5, -.5,
    -.5, +.5, -.5,
    +.5, -.5, -.5,
    -.5, -.5, -.5,
    +.5, +.5, +.5,
    -.5, +.5, +.5,
    -.5, -.5, +.5,
    +.5, -.5, +.5,
  ]
  indices = UInt32[
    3, 2, 6, 7, 4, 2, 0,
    3, 1, 6, 5, 4, 1, 0
  ]

  vbo = Ref(GLuint(0))
  vao = Ref(GLuint(0))
  ebo = Ref(GLuint(0))

  glGenVertexArrays(1, vao)
  glBindVertexArray(vao[])

  glGenBuffers(1, vbo)
  glBindBuffer(GL_ARRAY_BUFFER, vbo[])
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)

  glEnableVertexAttribArray(0)
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(Float32), C_NULL)

  glGenBuffers(1, ebo)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo[])
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW)

  (ebo=ebo[], num_indices=length(indices))
end

# Global variables needed for each render
const shader_program = Ref{GLuint}(0)
const ebo = Ref{GLuint}(0)
const uni_world = Ref{GLint}(0)
const num_indices = Ref{GLsizei}(0)

function init()
  shader_program[] = getProgram()
  uni_world[] = glGetUniformLocation(shader_program[], "gWorld")
  (ebo[], num_indices[]) = getEbo()
end

function renderFrame(g_world::Matrix{Float32})
  glUseProgram(shader_program[])
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo[])
  glUniformMatrix4fv(uni_world[], 1, GL_FALSE, pointer(g_world))
  glDrawElements(GL_TRIANGLE_STRIP, num_indices[], GL_UNSIGNED_INT, C_NULL)
end

end
