class_name AnalystShift
extends RefCounted
## Pure shift rules, separate from the interface and scenario content.

const MAX_STRIKES := 3
const EMAIL_QUOTA := 8
const DURATION := 300.0
const REQUIRED_ACCURACY := 0.75
var emails: Array = []
var decisions: Dictionary = {}
var correct := 0
var strikes := 0
var false_positives := 0
var missed_phishing := 0
var elapsed := 0.0
var decision_seconds := 0.0

func load_content() -> Error:
	var file := FileAccess.open("res://data/day_01.json", FileAccess.READ)
	if file == null:
		return ERR_FILE_CANT_OPEN
	var data = JSON.parse_string(file.get_as_text())
	if not data is Array or data.size() != EMAIL_QUOTA:
		return ERR_PARSE_ERROR
	for entry in data:
		if not entry is Dictionary:
			return ERR_INVALID_DATA
		for key in ["id", "sender", "address", "subject", "body", "link_label", "link_target", "attachment", "phishing", "explanation"]:
			if not entry.has(key):
				return ERR_INVALID_DATA
		if not entry.phishing is bool:
			return ERR_INVALID_DATA
		for key in ["id", "sender", "address", "subject", "body", "link_label", "link_target", "attachment", "explanation"]:
			if not entry[key] is String:
				return ERR_INVALID_DATA
		for previous in emails:
			if previous.id == entry.id:
				return ERR_INVALID_DATA
		emails.append(entry)
	return OK

func decide(index: int, quarantine: bool) -> Dictionary:
	if finished() or index < 0 or index >= emails.size() or decisions.has(index):
		return {}
	var matched: bool = quarantine == emails[index].phishing
	var result := {"correct": matched, "quarantine": quarantine, "seconds": decision_seconds}
	decisions[index] = result
	decision_seconds = 0.0
	if matched:
		correct += 1
	else:
		strikes += 1
		if quarantine:
			false_positives += 1
		else:
			missed_phishing += 1
	return result

func accuracy() -> float:
	return float(correct) / decisions.size() if not decisions.is_empty() else 0.0

func finished() -> bool:
	return strikes >= MAX_STRIKES or decisions.size() == emails.size() or elapsed >= DURATION

func passed() -> bool:
	return decisions.size() == emails.size() and strikes < MAX_STRIKES and accuracy() >= REQUIRED_ACCURACY
