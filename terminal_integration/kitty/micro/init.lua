local micro = import("micro")
local config = import("micro/config")
local shell = import("micro/shell")
local filepath = import("path/filepath")

function init()
    config.TryBindKey("Alt-i", "lua:initlua.chatai", true)
end

function onBufPaneOpen(pane)
    buf = pane.buf
    local fullPath = filepath.Abs(buf.Path)
    local ext = filepath.Ext(fullPath)

    if ext == ".md" then
        config.SetGlobalOption("softwrap", "on")
        config.SetGlobalOption("wordwrap", "on")
    else
        config.SetGlobalOption("softwrap", "off")
        config.SetGlobalOption("wordwrap", "off")
    end
end


function onExit(output, args)
    local buf = args[1]
    buf:ReOpen()
    micro.InfoBar():Message("Done!")
end

function chatai(bp)
    local buf = bp.Buf
    local fullPath = filepath.Abs(buf.Path)
    local command = "source <ENVIRONMENT_ACTIVATION> && python <RUN_SCRIPT> ".. fullPath
    buf:Save()
    micro.InfoBar():Message("Generating response...")
    shell.JobStart(command, nil, nil, onExit, buf)
end
