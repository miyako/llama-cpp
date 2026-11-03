property code : Integer
property message : Text
property models : Collection
Class constructor($code : Integer; $message : Text; $models : cs.models)
	This.code:=$code
	This.message:=$message
	This.models:=$models.models
