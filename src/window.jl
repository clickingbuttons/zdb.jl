module Window

using ModernGL
using GLFW

key_callbacks = []
click_callbacks = []
cursor_move_callbacks = []
cursor_enter_callbacks = []
scroll_callbacks = []

function createWindow()
  GLFW.DefaultWindowHints()
  GLFW.WindowHint(GLFW.RESIZABLE, GL_FALSE)
  GLFW.WindowHint(GLFW.SAMPLES, 16)

  window = GLFW.CreateWindow(1920, 1080, "GLFW.jl")
  Base.exit_on_sigint(false)
  @assert window != C_NULL "could not open window with GLFW3."
  GLFW.MakeContextCurrent(window)

  @info "Renderder: $(unsafe_string(glGetString(GL_RENDERER)))"
  @info "OpenGL version supported: $(unsafe_string(glGetString(GL_VERSION)))"

  GLFW.SetCharModsCallback(window, (window, char, mods) -> begin
    #println("char: $char, mods: $mods")
    foreach(cb -> cb(window, char, mods), key_callbacks)
  end)
  GLFW.SetMouseButtonCallback(window, (window, button, action, mods) -> begin
    #println("$button $action")
    foreach(cb -> cb(window, button, action, mods), click_callbacks)
  end)
  GLFW.SetCursorPosCallback(window, (window, xoff, yoff) -> begin
    #println("mouse: $xoff $yoff")
    foreach(cb -> cb(window, xoff, yoff), cursor_move_callbacks)
  end)
  GLFW.SetCursorEnterCallback(window, (window, entered) -> begin
    #println("enter: $entered")
    foreach(cb -> cb(window, entered), cursor_enter_callbacks)
  end)
  GLFW.SetScrollCallback(window, (window, xoff, yoff) -> begin
    #println("scroll: $xoff, $yoff")
    foreach(cb -> cb(window, xoff, yoff), scroll_callbacks)
  end)
  function onResize(_, w, h)
    println("resize: $w x $h")
    glViewport(0, 0, w, h)
  end
  GLFW.SetWindowSizeCallback(window, onResize)
  
  window
end

end

