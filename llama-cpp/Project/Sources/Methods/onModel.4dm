//%attributes = {}
#DECLARE($status : Object; $options : Object)

If ($status.success)
	
Else 
	
	var $error : cs:C1710.event.error
	$error:=cs:C1710.event.error.new(2; "failed to load model!"; This:C1470.that.models())
	
	If (This:C1470.event#Null:C1517) && (OB Instance of:C1731(This:C1470.event; cs:C1710.event.event))
		This:C1470.event.onError.call(This:C1470.that; $options; $error)
	End if 
	
	var $workers : cs:C1710.workers.workers
	$workers:=cs:C1710.workers.workers.new()
	$workers.remove($options.port)
	
End if 