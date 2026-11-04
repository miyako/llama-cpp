//%attributes = {"invisible":true,"preemptive":"capable"}
#DECLARE($value : Real)->$text : Text

// String() uses the system decimal separator (e.g. "0,3"); llama-server expects "0.3"
$text:=JSON Stringify:C1217($value)
