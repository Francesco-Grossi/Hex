## MapEditorBridge.gd
## Autoload singleton (add to Project → Project Settings → Autoload).
## Its only job is to carry the pending load path across a scene change,
## since scene transitions wipe all local state.
##
## Setup:
##   Project Settings → Autoload → add this file with name "MapEditorBridge"

extends Node

## Set by MainMenu before switching scenes; read + cleared by MapEditor._ready().
var pending_load_path: String = ""
