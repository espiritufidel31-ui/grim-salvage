extends RefCounted
const FILE="user://station-v1.json"
static func load_game():
	for name in [FILE,FILE+".previous"]:
		if not FileAccess.file_exists(name):continue
		var value=JSON.parse_string(FileAccess.get_file_as_string(name))
		if typeof(value)==TYPE_DICTIONARY and value.get("version",0)==1 and typeof(value.get("profile"))==TYPE_DICTIONARY:
			return value
	return {}
static func write_game(profile,options,run_data):
	var file=FileAccess.open(FILE+".new",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify({"version":1,"profile":profile,"settings":options,"run":run_data}));file.flush();file.close()
	var path=ProjectSettings.globalize_path(FILE)
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(path+".previous")
		if DirAccess.rename_absolute(path,path+".previous")!=OK:return false
	if DirAccess.rename_absolute(path+".new",path)!=OK:
		if FileAccess.file_exists(FILE+".previous"):DirAccess.rename_absolute(path+".previous",path)
		return false
	return true
