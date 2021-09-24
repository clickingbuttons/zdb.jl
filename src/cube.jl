module Cube

using Random
using ModernGL
using GLFW
import ModernGL: @glfunc, GLFunc, getprocaddress_e
using ..Aggs
using ..GL
using ..Axes

# Global variables needed for each render
const program = Ref{GLuint}(0)
const ebo = Ref{GLuint}(0)
const vao = Ref{GLuint}(0)
const uni_world = Ref{GLint}(0)

symbol = ""
minute_bucket_ranges = Dict{String, Aggs.MinuteBucketRange}()
minute_bucket_keys = String[]

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
  +1, +1, -1,
  -1, +1, -1,
  +1, -1, -1,
  -1, -1, -1,
  +1, +1, +1,
  -1, +1, +1,
  -1, -1, +1,
  +1, -1, +1,
]
const indices = UInt32[
  3, 2, 6, 7, 4, 2, 0,
  3, 1, 6, 5, 4, 1, 0
]
const max_num_cubes = 1_000_000
const GL_MAP_PERSISTENT_BIT = 0x0040
const GL_MAP_COHERENT_BIT = 0x0080
@glfunc glBufferStorage(target::GLenum, size::GLsizei, data::Ptr{Cvoid}, flags::GLbitfield)::Cvoid
num_cubes = 0
models = Float32[]
colors = Float32[]

function write_cubes(minute_bucket_range::Aggs.MinuteBucketRange)
  global num_cubes = 0
  scale_x = Float32(Axes.x / (last(minute_bucket_range.buckets).time - first(minute_bucket_range.buckets).time))
  price_range = minute_bucket_range.range_price.stop - minute_bucket_range.range_price.start
  scale_y = Float32(Axes.y / price_range)
  scale_yy = Float32(Axes.y / 2 / (price_range / minute_bucket_range.min_price_distance))
  scale_z = Float32(Axes.z / minute_bucket_range.max_volume)
  i = 1
  for bucket in minute_bucket_range.buckets
    for (price, volume) in bucket.prices
      transform = GL.translate(
        -Float32((bucket.time - minute_bucket_range.buckets[1].time) * scale_x),
        Float32((price - minute_bucket_range.range_price.start) * scale_y),
        -scale_z * volume / 2
       ) * GL.scale(scale_x / 2, scale_yy, scale_z * volume / 2)
      for v in transform
        global models[i] = v
        i += 1
      end
      global num_cubes += 1
    end
  end

  #glBufferData(GL_ARRAY_BUFFER, sizeof(models), models, GL_STATIC_DRAW)
  # color
  Random.seed!(1234)
  for i = 0:num_cubes - 1
    colors[i * 3 + 1] = rand(Float32)
    colors[i * 3 + 2] = rand(Float32)
    colors[i * 3 + 3] = rand(Float32)
  end
  #glBufferData(GL_ARRAY_BUFFER, sizeof(colors), colors, GL_STATIC_DRAW)
  println("num_cubes $(num_cubes)")
end

function init(window::GLFW.Window)
  init_program()
  uni_world[] = glGetUniformLocation(program[], "gWorld")
  # position
  vbo = Ref{GLuint}(0)
  glGenBuffers(1, vbo)
  glBindBuffer(GL_ARRAY_BUFFER, vbo[])
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)

  glGenVertexArrays(1, vao)
  glBindVertexArray(vao[])
  glEnableVertexAttribArray(0)
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(Float32), C_NULL)

  # model
  mbo = Ref{GLuint}(0)
  glGenBuffers(1, mbo)
  glBindBuffer(GL_ARRAY_BUFFER, mbo[])
  flags = GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT
  max_num_floats = max_num_cubes * 16
  # https://ferransole.wordpress.com/2014/06/08/persistent-mapped-buffers/
  glBufferStorage(GL_ARRAY_BUFFER, max_num_floats * 4, C_NULL, flags)
  modelPtr = convert(Ptr{Float32}, glMapBufferRange(GL_ARRAY_BUFFER, C_NULL, max_num_floats * 4, flags))
  global models = unsafe_wrap(Array, modelPtr, (max_num_floats,))
  # Mat4s take 4 attribute arrays
  mbo_loc = glGetAttribLocation(program[], "model")
  for i = 0:3
    loc = mbo_loc + i
    glEnableVertexAttribArray(loc)
    offset = Ptr{Cvoid}(4 * i * sizeof(Float32))
    glVertexAttribPointer(loc, 4, GL_FLOAT, GL_FALSE, 4 * 4 * sizeof(Float32), offset)
    glVertexAttribDivisor(loc, 1)
  end

  # color
  cbo = Ref{GLuint}(0)
  glGenBuffers(1, cbo)
  glBindBuffer(GL_ARRAY_BUFFER, cbo[])
  glEnableVertexAttribArray(1)
  glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(Float32), C_NULL)
  glVertexAttribDivisor(1, 1)
  max_num_floats = max_num_cubes * 3
  glBufferStorage(GL_ARRAY_BUFFER, max_num_floats * 4, C_NULL, flags)
  colorPtr = convert(Ptr{Float32}, glMapBufferRange(GL_ARRAY_BUFFER, C_NULL, max_num_floats * 4, flags))
  global colors = unsafe_wrap(Array, colorPtr, (max_num_floats,))

  # indices
  glGenBuffers(1, ebo)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo[])
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW)
end

function renderFrame(g_world::Matrix{Float32})
  glUseProgram(program[])
  glBindVertexArray(vao[])
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo[])
  glUniformMatrix4fv(uni_world[], 1, GL_FALSE, pointer(g_world))
  glDrawElementsInstanced(GL_TRIANGLE_STRIP, length(indices), GL_UNSIGNED_INT, C_NULL, num_cubes)
end

function key_callback(_window, key, _scancode, action, mods)
  if key == GLFW.KEY_N && action == GLFW.RELEASE
    num_symbols = length(minute_bucket_keys)
    symbol_index = findfirst(s -> s == symbol, minute_bucket_keys)
    if mods == GLFW.MOD_SHIFT
      symbol_index -= 1
      if symbol_index < 1
        println("start")
        symbol_index = num_symbols
      end
    else
      symbol_index += 1
      if symbol_index > num_symbols
        println("end")
        symbol_index = 1
      end
    end
    global symbol = minute_bucket_keys[symbol_index]
    println(symbol_index, " ", symbol)
    write_cubes(minute_bucket_ranges[symbol])
  end
end

function loadDate(date::String)
  global minute_bucket_ranges = Aggs.get_minute_bucket_ranges(date)
  global minute_bucket_keys = collect(keys(minute_bucket_ranges))
  global symbol = first(minute_bucket_keys)
  write_cubes(minute_bucket_ranges[symbol])
end

function loadSymbol(sym::String)
  global symbol = sym
  write_cubes(minute_bucket_ranges[symbol])
end

end
