tool # Required for editor scripts
extends EditorScript

func _run():
    var file_path = ARGV[0] # Passed from command line
    var script = load(file_path)
    if script:
        print("Reloaded: ", file_path)
    else:
        print("Failed to reload: ", file_path)
