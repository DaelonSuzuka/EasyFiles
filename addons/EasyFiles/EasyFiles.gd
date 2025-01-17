extends Node
# This script simplyfies all kinds of file operations.
# This costs you some control over the files you might not use anyway.



signal file_modified(path)


var _dir := Directory.new() setget _not_setter # protected var
var _test_file := File.new() setget _not_setter # protected var
var _file_moinitor_timer := Timer.new() setget _not_setter # protected var
var _files_to_monitor := [] setget _not_setter # protected var
var _files_last_modified := [] setget _not_setter # protected var


func _not_setter(__):
	pass


func _ready():
	# set up check file timer
	add_child(_file_moinitor_timer)
	_file_moinitor_timer.start(1)
	_file_moinitor_timer.connect("timeout", self, "force_file_modification_check")



## file modification checks
###############################
func add_file_monitor(path:String)->int:
	if _files_to_monitor.has(path): return ERR_ALREADY_EXISTS
	# I don' know if relative paths will work but might as well allow them
	if !(path.is_abs_path() or path.is_rel_path()): ERR_FILE_BAD_PATH
	_files_to_monitor.push_back(path)
	_files_last_modified.push_back(_test_file.get_modified_time(path))
	return OK


func remove_file_monitor(path:String)->int:
	if !_files_to_monitor.has(path): return ERR_DOES_NOT_EXIST
	_files_last_modified.remove(_files_to_monitor.find(path))
	_files_to_monitor.erase(path)
	return OK


func force_file_modification_check()->void:
	for idx in range(_files_to_monitor.size()):
		var mod_time := _test_file.get_modified_time(_files_to_monitor[idx])
		if mod_time == _files_last_modified[idx]: continue
		emit_signal("file_modified", _files_to_monitor[idx])
		_files_last_modified[idx] = mod_time


func get_monitored_files()->Array:
	return _files_to_monitor


func set_file_monitor_intervall(time:float=1)->void:
	_file_moinitor_timer.start(time)


func get_file_monitor_intervall()->float:
	return _file_moinitor_timer.wait_time


func pause_file_monitoring()->void:
	_file_moinitor_timer.paused = true


func resume_file_monitoring()->void:
	_file_moinitor_timer.paused = false
###########################################


## general Folder operations
############################
func copy_file(from:String, to:String)->int:
	return _dir.copy(from, to)

func delete_file(path:String)->int:
	return _dir.remove(path)

func create_folder(path:String)->int:
	return _dir.make_dir_recursive(path)

func rename(from: String, to: String)->int:
	return _dir.rename(from, to)

func path_exists(path:String)->bool:
	if path.match("*.*"):
		return _dir.file_exists(path)
	return _dir.dir_exists(path)
###########################################


## json
#######
func read_json(path:String, key:="", compression=-1):
	return parse_json(read_text(path, key, compression))

func write_json(path:String, data, key:="", compression=-1)->int:
	return write_text(path, to_json(data), key, compression)
###########################################


## text
#######
func read_text(path:String, key:="", compression=-1)->String:
	var data := ""
	var err : int
	err = _open_read(path, key, compression)
	
	if err==OK:
		data = _test_file.get_as_text()
	else:
		prints("Couldn't read", path, "ErrorCode:", err)
	
	_test_file.close()
	return data


func write_text(path:String, text:String, key:="", compression=-1)->int:
	var err : int
	err = _open_write(path, key, compression)
	
	if err==OK:
		_test_file.store_string(text)
	else:
		prints("Couldn't write", path, "ErrorCode:", err)
	
	_test_file.close()
	return err
###########################################


## Any Variable
###############
func read_variant(path:String, key:="", compression=-1):
	var data
	var err : int
	err = _open_read(path, key, compression)
	
	if err==OK:
		data = _test_file.get_var(true)
	else:
		prints("Couldn't read", path, "ErrorCode:", err)
	
	_test_file.close()
	return data


func write_variant(path:String, value, key:="", compression=-1)->int:
	var err : int
	err = _open_write(path, key, compression)
	
	if err==OK:
		_test_file.store_var(value, true)
	else:
		prints("Couldn't write", path, "ErrorCode:", err)
	
	_test_file.close()
	return err
###########################################


## Binary
#########
func read_bytes(path:String, key:="", compression=-1)->PoolByteArray:
	var data := PoolByteArray([])
	var err : int
	err = _open_read(path, key, compression)
	
	if err==OK:
		data = _test_file.get_buffer(_test_file.get_len())
	else:
		prints("Couldn't read", path, "ErrorCode:", err)
	
	_test_file.close()
	return data


func write_bytes(path:String, value:PoolByteArray, key:="", compression:=-1)->int:
	var err : int
	
	err = _open_write(path, key, compression)
	
	if err==OK:
		_test_file.store_buffer(value)
	else:
		prints("Couldn't write", path, "ErrorCode:", err)
	
	_test_file.close()
	return err
###########################################


## CSV
######
func read_csv(path:String, key:="", custom_delimiter=",", compression=-1)->Array:
	var data := []
	var err : int
	err = _open_read(path, key, compression)
	
	if err==OK:
		while _test_file.get_len() > _test_file.get_position():
			data.push_back(_test_file.get_csv_line(custom_delimiter))
	else:
		prints("Couldn't read", path, "ErrorCode:", err)
	
	_test_file.close()
	return data


func write_csv(path:String, value:Array, custom_delimiter=",", key:="", compression=-1)->int:
	var err : int
	
	# validate value
	if !value is Array: return ERR_INVALID_DATA
	for i in range(value.size()):
		if value[i] is PoolStringArray: continue
		if value[i] is Array:
			value[i] = PoolStringArray(value[i])
			continue
		value[i] = PoolStringArray()
	
	err = _open_write(path, key, compression)
	
	if err==OK:
		for line in value:
			_test_file.store_csv_line(line, custom_delimiter)
			_test_file.flush()
	else:
		prints("Couldn't write", path, "ErrorCode:", err)
	
	_test_file.close()
	return err
###########################################



## file search
##############
func get_files_in_directory(path:String, recursive=false, filter:="*"):
	var found = []
	var dirs = []
	if !path.ends_with("/"): path += "/"
	
	var dir := Directory.new()
	if dir.open(path) == OK:
		# warning-ignore:return_value_discarded
		dir.list_dir_begin(true, true)
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				dirs.push_back(file_name)
			else:
				if file_name.match(filter):
					found.push_back(path+file_name)
			file_name = dir.get_next()
	else:
		return []
	
	if !recursive: return found
	
	#check other dirs if recursive
	for new_dir in dirs:
		for file in get_files_in_directory(path+new_dir+"/", true, filter):
			found.push_back(file)
	
	return found
###########################################


## Helper Functions

func _open_read(path:String, key="", compression=-1)->int:
	if _test_file.is_open(): return ERR_BUSY
	if key != "":
		return _test_file.open_encrypted_with_pass(path, _test_file.READ, key)
	elif compression != -1:
		if compression < 0 or compression > 3: return ERR_INVALID_PARAMETER
		return _test_file.open_compressed(path, _test_file.READ, compression)
	else:
		return _test_file.open(path, _test_file.READ)


func _open_write(path:String, key="", compression=-1)->int:
	if _test_file.is_open(): return ERR_BUSY
	if key != "":
		return _test_file.open_encrypted_with_pass(path, _test_file.WRITE, key)
	elif compression != -1:
		if compression < 0 or compression > 3: return ERR_INVALID_PARAMETER
		return _test_file.open_compressed(path, _test_file.WRITE, compression)
	else:
		return _test_file.open(path, _test_file.WRITE)
###########################################


