//%attributes = {}
#DECLARE($status : Object; $options : Object)

If ($status.success)
	
Else 
	
	var $error : cs:C1710.event.error
	$error:=cs:C1710.event.error.new(2; "failed to load model!"; This:C1470.models())
	
	If ($options.event#Null:C1517) && (OB Instance of:C1731($options.event; cs:C1710.event.event))
		$options.event.onError.call(This:C1470; $options; $error)
	End if 
	
	var $workers : cs:C1710.workers.workers
	$workers:=cs:C1710.workers.workers.new()
	$workers.remove($options.port)
	
End if 