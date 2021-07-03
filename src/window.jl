module Window

using ModernGL
using GLFW

function create_window()
  GLFW.DefaultWindowHints()
  GLFW.WindowHint(GLFW.RESIZABLE, GL_FALSE)
  GLFW.WindowHint(GLFW.SAMPLES, 16)

  window = GLFW.CreateWindow(1000, 1000, "GLFW.jl")
  Base.exit_on_sigint(false)
  @assert window != C_NULL "could not open window with GLFW3."
  GLFW.MakeContextCurrent(window)

  @info "Renderder: $(unsafe_string(glGetString(GL_RENDERER)))"
  @info "OpenGL version supported: $(unsafe_string(glGetString(GL_VERSION)))"

  GLFW.SetCharModsCallback(window, (_, c, mods) -> println("char: $c, mods: $mods"))
  GLFW.SetMouseButtonCallback(window, (_, button, action, mods) -> println("$button $action"))
  #GLFW.SetCursorPosCallback(window, (_, xoff, yoff) -> println("mouse: $xoff $yoff"))
  GLFW.SetScrollCallback(window, (_, xoff, yoff) -> println("scroll: $xoff, $yoff"))
  function onResize(_, w, h)
    println("window size: $w x $h")
    glViewport(0, 0, w, h)
  end
  GLFW.SetWindowSizeCallback(window, onResize)
  
  window
end

end

