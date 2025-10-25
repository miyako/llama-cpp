property _complete; hideWindow : Boolean
property dataType; encoding : Text
property variables : Object
property _commands; _messages; _contexts : Collection
property timeout : Variant
property _worker : 4D:C1709.SystemWorker
property onResponse; _onResponse; onTerminate; _onTerminate : 4D:C1709.Function
property _instance : cs:C1710._CLI
property currentDirectory : 4D:C1709.Folder
property SYSTEM_WORKER_CONTEXT : Object

Class constructor($CLI : cs:C1710._CLI)
	
	//use default event handler if not defined in subclass definition
	For each ($event; ["onData"; "onDataError"; "onError"; "onResponse"; "onTerminate"])
		If (Not:C34(OB Instance of:C1731(This:C1470[$event]; 4D:C1709.Function)))
			This:C1470[$event]:=This:C1470._onEvent
		End if 
	End for each 
	
	This:C1470.timeout:=Null:C1517
	This:C1470.dataType:="text"
	This:C1470.encoding:="UTF-8"
	This:C1470.variables:={}
	This:C1470.currentDirectory:=$CLI.currentDirectory
	This:C1470.hideWindow:=True:C214
	
	This:C1470._instance:=$CLI
	This:C1470._commands:=[]
	This:C1470._messages:=[]
	This:C1470._contexts:=[]
	This:C1470._worker:=Null:C1517
	This:C1470._complete:=False:C215  //flag to indicate whether we have queued commands
	This:C1470.SYSTEM_WORKER_CONTEXT:={}  //kvp to manage context
	
Function get commands()->$commands : Collection
	
	$commands:=This:C1470._commands
	
Function get complete()->$complete : Boolean
	
	$complete:=This:C1470._complete
	
Function get instance()->$instance : cs:C1710._CLI
	
	$instance:=This:C1470._instance
	
Function get worker()->$worker : 4D:C1709.SystemWorker
	
	$worker:=This:C1470._worker
	
	//MARK:-public methods
	
Function execute($command : Variant; $message : Variant; $context : Variant) : cs:C1710._CLI_Controller
	
	var $commands : Collection
	var $messages : Collection
	var $contexts : Collection
	
	Case of 
		: (Value type:C1509($command)=Is text:K8:3)
			$commands:=[$command]
			$messages:=[$message]
			$contexts:=[$context]
		: (Value type:C1509($command)=Is collection:K8:32)
			$commands:=$command
			If (Value type:C1509($message)=Is collection:K8:32) && ($message.length=$commands.length)
				$messages:=$message
			Else 
				$messages[$commands.length-1]:=Null:C1517
			End if 
			If (Value type:C1509($context)=Is collection:K8:32) && ($context.length=$commands.length)
				$contexts:=$context
			Else 
				$contexts[$commands.length-1]:=Null:C1517
			End if 
	End case 
	
	If ($commands#Null:C1517) && ($commands.length#0)
		
		This:C1470._commands.combine($commands)
		This:C1470._messages.combine($messages)
		This:C1470._contexts.combine($contexts)
		
		If (This:C1470._worker=Null:C1517)
			This:C1470._onResponse:=This:C1470.onResponse
			This:C1470.onResponse:=This:C1470._onExecute
			This:C1470._onTerminate:=This:C1470.onTerminate
			This:C1470.onTerminate:=This:C1470._onComplete
			This:C1470._execute()
		End if 
		
	End if 
	
	return This:C1470
	
Function terminate()
	
	This:C1470._abort()
	
	If (This:C1470._worker#Null:C1517)
		This:C1470._worker.terminate()
	End if 
	
	This:C1470._terminate()
	
	//MARK:-private methods
	
Function _onEvent($worker : 4D:C1709.SystemWorker; $params : Object)
	
	Case of 
		: ($params.type="data") && ($worker.dataType="text")
			
		: ($params.type="data") && ($worker.dataType="blob")
			
		: ($params.type="error")
			
		: ($params.type="termination")
			
		: ($params.type="response")
			
	End case 
	
Function _onExecute($worker : 4D:C1709.SystemWorker; $params : Object)
	
	If (This:C1470._commands.length=0)
		This:C1470._abort()
	Else 
		This:C1470._execute()
	End if 
	
	If (OB Instance of:C1731(This:C1470._onResponse; 4D:C1709.Function))
		$params.context:=This:C1470.SYSTEM_WORKER_CONTEXT[String:C10($worker.pid)]
		This:C1470._onResponse.call(This:C1470; $worker; $params)
	End if 
	
Function _execute()
	
	This:C1470._complete:=False:C215
	
	This:C1470._worker:=4D:C1709.SystemWorker.new(This:C1470._commands.shift(); This:C1470)
	
	This:C1470.SYSTEM_WORKER_CONTEXT[String:C10(This:C1470._worker.pid)]:=This:C1470._contexts.shift()
	
	var $message : Variant
	$message:=This:C1470._messages.shift()
	
	var $vt : Integer
	$vt:=Value type:C1509($message)
	
	If ($vt=Is object:K8:27) && (OB Instance of:C1731($message; 4D:C1709.Blob))
		$vt:=Is BLOB:K8:12
	End if 
	
	Case of 
		: ($vt=Is object:K8:27) || ($vt=Is collection:K8:32)
			
			This:C1470._worker.postMessage(JSON Stringify:C1217($message))
			This:C1470._worker.closeInput()
			
		: ($vt=Is BLOB:K8:12) || ($vt=Is text:K8:3)
			
			This:C1470._worker.postMessage($message)
			This:C1470._worker.closeInput()
			
		: ($vt=Is real:K8:4) || ($vt=Is integer:K8:5) || ($vt=Is boolean:K8:9) || ($vt=Is date:K8:7) || ($vt=Is time:K8:8)
			
			This:C1470._worker.postMessage(String:C10($message))
			This:C1470._worker.closeInput()
			
	End case 
	
Function _onComplete($worker : 4D:C1709.SystemWorker; $params : Object)
	
	If (OB Instance of:C1731(This:C1470._onTerminate; 4D:C1709.Function))
		This:C1470._onTerminate.call(This:C1470; $worker; $params)
	End if 
	
	If (This:C1470.complete)
		This:C1470._terminate()
	End if 
	
Function _abort()
	
	This:C1470._complete:=True:C214
	This:C1470._commands.clear()
	
Function _terminate()
	
	This:C1470.onResponse:=This:C1470._onResponse
	This:C1470.onTerminate:=This:C1470._onTerminate
	This:C1470._worker:=Null:C1517