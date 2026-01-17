Class constructor
	
Function _onTCP($status : Object; $options : Object)
	
	If ($status.success)
		
		$name:=$options.name
		OB REMOVE:C1226($options; "name")
		
		CALL WORKER:C1389($name; Formula:C1597(start); $options; Formula:C1597(onModel))
		
	Else 
		
		var $statuses : Text
		$statuses:="TCP port "+String:C10($status.port)+" is aready used by process "+$status.PID.join(",")
		var $error : cs:C1710.event.error
		$error:=cs:C1710.event.error.new(1; $statuses)
		
		If ($options.event#Null:C1517) && (OB Instance of:C1731($options.event; cs:C1710.event.event))
			$options.event.onError.call(This:C1470; $options; $error)
		End if 
		
	End if 
	
Function terminate()
	
	var $ONNX : cs:C1710.workers.worker
	$ONNX:=cs:C1710.workers.worker.new(cs:C1710._server)
	$ONNX.terminate()