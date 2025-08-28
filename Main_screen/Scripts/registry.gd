extends Control

# Constants
const ADMIN_PASSWORD = "CMC"
const PATIENT_REGISTER_PATH = "res://Main_screen/patient_register.tres"
const MAIN_SCENE_PATH = "res://Main_screen/Scenes/main.tscn"
const SELECT_GAME_SCENE_PATH = preload("res://Main_screen/Scenes/select_game.tscn")

# Enums for better type safety
enum Gender { MALE, FEMALE, OTHERS, UNSPECIFIED = -1 }
enum Hand { LEFT, RIGHT, AMBIDEXTROUS, UNSPECIFIED = -1 }
enum AffectedHand { LEFT, RIGHT, BOTH, UNSPECIFIED = -1 }

# Node references - cached for performance
@onready var patient_db: PatientDetails = load(PATIENT_REGISTER_PATH)
@onready var patient_list = $TextureRect/PatientList
@onready var auth_window = $TextureRect/Auth
@onready var patient_display = $TextureRect/Patient_display
@onready var invalid_details = $TextureRect/InvalidDetails
@onready var login_to_patient = $TextureRect/LoginSelectPatient
@onready var patient_name_label: Label = $TextureRect/LoginSelectPatient/PatientName

# Form field references
@onready var patient_name_field = $TextureRect/PatientName
@onready var age_field = $TextureRect/Age
@onready var hosp_id_field = $TextureRect/HospID
@onready var gender_field = $TextureRect/Gender
@onready var stroke_time_field = $TextureRect/StrokeTime
@onready var dominant_hand_field = $TextureRect/DominantHand
@onready var affected_hand_field = $TextureRect/AffectedHand
@onready var comments_field = $TextureRect/AdditionalComments
@onready var password_field = $TextureRect/Auth/password

# State variables
var patient_selected: int = -1
var cached_patients: Array = []
var json_path: String
var endgame : bool

func _ready() -> void:
	allpatients = patient_db.list_all_patients()
	_update_plist()
	
func _update_plist() -> void:
	patient_list.clear()
	allpatients = patient_db.list_all_patients()
	var _h_id = []
	for _p in allpatients:
		_h_id.append(_p['hospital_id'] +" "+ _p['name'])
		patient_list.add_item(_p['hospital_id'] +" "+ _p['name'])

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Main_screen/main.tscn")


func _on_exit_button_pressed() -> void:
	get_tree().quit()

func save_json(content):
	var file = FileAccess.open(path, FileAccess.WRITE)
	print(path)
	file.store_string(JSON.stringify(content.list_all_patients()))
	file.close()
	GlobalScript._path_checker()
	
func _on_register_patient_pressed() -> void:
	var patient_name = $TextureRect/PatientName.text
	var age = $TextureRect/Age.text
	var hosp_id = $TextureRect/HospID.text
	var gender_id = $TextureRect/Gender.selected
	var stroke_time = int($TextureRect/StrokeTime.text)
	var gender:String
	
	match gender_id:
		0:
			gender = "Male"
		1:
			gender = "Female"
		2:
			gender = "Others"
		-1:
			gender = "Unspecified"
	
	var dominant_hand:String
	match $TextureRect/DominantHand.selected:
		0:
			dominant_hand = "Left"
		1:
			dominant_hand = "Right"
		2:
			dominant_hand = "Ambidextrous"
		-1:
			dominant_hand = "Unspecified"
			
	var affected_hand:String
	match $TextureRect/AffectedHand.selected:
		0:
			affected_hand = "Left"
		1:
			affected_hand = "Right"
		2:
			affected_hand = "Both"
		-1:
			affected_hand = "Unspecified"
	
	var comments = $TextureRect/AdditionalComments.text

	if patient_name != "" and hosp_id != "" and age !="":
		
		patient_db.add_patient(hosp_id, patient_name, int(age), gender, stroke_time, dominant_hand, affected_hand, comments)
		save_json(patient_db)
		ResourceSaver.save(patient_db, "res://Main_screen/patient_register.tres")
		_update_plist()
	else:
		invalid_details.show()
		print('enter details correctly')


func _on_patient_list_item_selected(index: int) -> void:
	patient_selected = index
	var current_patient = patient_db.list_all_patients()[patient_selected]
	print(current_patient)
	var text_display = "Hosp ID: " + current_patient['hospital_id'] +"\n" + \
						"Name: " +current_patient['name'] + "\n" + \
						"Age: " + str(current_patient['age']) + "\n" + \
						"Gender: " + current_patient['gender'] + "\n" + \
						"Diag time: " + str(current_patient['stroke_time']) + "\n" + \
						"Dominant hand: " + current_patient['dominant_hand'] + "\n" + \
						"Affected hand: " + current_patient['affected_hand'] + "\n" + \
						"Comments: " + "\n" + \
						current_patient['comments']
						
	if current_patient["affected_hand"] == "Left" or current_patient["affected_hand"] == "Right":
		GlobalSignals.selected_training_hand = current_patient["affected_hand"]
		

	elif current_patient["affected_hand"] == "Both":
		pass
		GlobalSignals.selected_training_hand = ""  
		
	
	patient_display.clear()
	patient_display.add_text(text_display)

func _on_patient_list_item_activated(index: int) -> void:
    if index < 0 or index >= cached_patients.size():
        return
        
    patient_selected = index
    login_to_patient.show()
    patient_name_label.text = patient_list.get_item_text(index)
    patient_name_label.visible = true

func _on_delete_pressed() -> void:
	auth_window.show()

func _on_delete_login_pressed() -> void:
	if $TextureRect/Auth/password.text == "CMC":
		if len(patient_db.list_all_patients()) != 0:
			patient_db.remove_patient(allpatients[patient_selected]['hospital_id'])
			save_json(patient_db)
			ResourceSaver.save(patient_db, "res://Main_screen/patient_register.tres")
			patient_list.clear()
			_update_plist()
			auth_window.hide()
	else:
		auth_window.hide()

func _on_login_button_pressed() -> void:
    if patient_selected < 0 or patient_selected >= cached_patients.size():
        return
        
    var current_patient = cached_patients[patient_selected]
    
    # Set global state
    patient_db.current_patient_id = current_patient['hospital_id']
    GlobalScript.change_patient()
    GlobalSignals.current_patient_id = current_patient['hospital_id']
    GlobalSignals.affected_hand = current_patient['affected_hand']
    
    _save_patient_data()
    get_tree().change_scene_to_packed(SELECT_GAME_SCENE_PATH)

# Window management
func _on_auth_close_requested() -> void:
    auth_window.hide()

func _on_close_button_pressed() -> void:
	invalid_details.hide()
	login_to_patient.hide()


func _on_patient_list_item_activated(index: int) -> void:
	patient_selected = index
	login_to_patient.show()
	var selected_text = patient_list.get_item_text(index)
	patient_name_label.text = selected_text
	patient_name_label.visible = true
	
func _on_login_button_pressed() -> void:
	var current_patient = allpatients[patient_selected]
	patient_db.current_patient_id = allpatients[patient_selected]['hospital_id']
	GlobalScript.change_patient()
	GlobalSignals.current_patient_id = allpatients[patient_selected]['hospital_id']
	GlobalSignals.affected_hand = current_patient["affected_hand"] 
	save_json(patient_db)
	
	ResourceSaver.save(patient_db, "res://Main_screen/patient_register.tres")
	get_tree().change_scene_to_file("res://Main_screen/select_game.tscn")
	
