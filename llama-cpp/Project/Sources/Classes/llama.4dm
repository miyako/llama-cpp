Class constructor($port : Integer; $file : 4D:C1709.File; $URL : Text; $options : Object; $event : cs:C1710._event)
	
	var $llama : cs:C1710.workers.worker
	$llama:=cs:C1710.workers.worker.new(cs:C1710._server)
	
	If (Not:C34($llama.isRunning($port)))
		
		If (Value type:C1509($file)#Is object:K8:27) || (Not:C34(OB Instance of:C1731($file; 4D:C1709.File))) || ($URL="")
			var $homeFolder : 4D:C1709.Folder
			$homeFolder:=Folder:C1567(fk home folder:K87:24).folder(".llama-cpp")
			$file:=$homeFolder.file("nomic-embed-text-v1.5.f16.gguf")
			$URL:="https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.f16.gguf"
		End if 
		
		If ($port=0) || ($port<0) || ($port>65535)
			$port:=8080
		End if 
		
		This:C1470.main($port; $file; $URL; $options; $event)
		
	End if 
	
Function onTCP($status : Object; $options : Object)
	
	If ($status.success)
		
		var $className : Text
		$className:=Split string:C1554(Current method name:C684; "."; sk trim spaces:K86:2).first()
		
		CALL WORKER:C1389($className; Formula:C1597(start); $options; Formula:C1597(onModel))
		
	Else 
		
		var $statuses : Text
		$statuses:="TCP port "+String:C10($status.port)+" is aready used by process "+$status.PID.join(",")
		var $error : cs:C1710._error
		$error:=cs:C1710._error.new(1; $statuses)
		
		If ($options.event#Null:C1517) && (OB Instance of:C1731($options.event; cs:C1710._event))
			$options.event.onError.call(This:C1470; $options; $error)
		End if 
		
		This:C1470.terminate()
		
	End if 
	
Function main($port : Integer; $file : 4D:C1709.File; $URL : Text; $options : Object; $event : cs:C1710._event)
	
	main({port: $port; file: $file; URL: $URL; options: $options; event: $event}; This:C1470.onTCP)
	
Function terminate()
	
	var $llama : cs:C1710.workers.worker
	$llama:=cs:C1710.workers.worker.new(cs:C1710._server)
	$llama.terminate()