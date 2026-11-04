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
property _lifecycles : Collection
property _active : Object
property _generation : Integer

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
	This:C1470._lifecycles:=[]
	This:C1470._active:=Null:C1517
	This:C1470._generation:=0
	
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
		
		If (This:C1470._worker=Null:C1517) && (This:C1470._commands.length=0) && (This:C1470._messages.length=0) && (This:C1470._contexts.length=0)
			This:C1470._complete:=True:C214
			This:C1470._execute($commands; $messages; $contexts)
		Else
			This:C1470._commands.combine($commands)
			This:C1470._messages.combine($messages)
			This:C1470._contexts.combine($contexts)
			This:C1470._complete:=False:C215

			If (This:C1470._worker=Null:C1517)
				This:C1470._execute()
			End if
		End if 
		
	End if 
	
	return This:C1470
	
Function abortQueue()
	
	This:C1470._complete:=True:C214
	This:C1470._commands.clear()
	This:C1470._messages.clear()
	This:C1470._contexts.clear()

Function terminate()
	
	var $worker : 4D:C1709.SystemWorker
	$worker:=This:C1470._worker
	This:C1470.abortQueue()
	This:C1470._terminate()
	If ($worker#Null:C1517)
		$worker.terminate()
	End if
	
	//MARK:-private methods
	
Function _onEvent($worker : 4D:C1709.SystemWorker; $params : Object)
	
	Case of 
		: ($params.type="data") && ($worker.dataType="text")
			
		: ($params.type="data") && ($worker.dataType="blob")
			
		: ($params.type="error")
			
		: ($params.type="termination")
			
		: ($params.type="response")
			
	End case 
	
Function _lifecycle($worker : 4D:C1709.SystemWorker)->$lifecycle : Object

	var $item : Object
	For each ($item; This:C1470._lifecycles)
		If ([$item.worker].indexOf($worker)=0)
			$lifecycle:=$item
			return
		End if
	End for each

Function _owns($lifecycle : Object)->$owns : Boolean

	$owns:=False:C215
	If ($lifecycle#Null:C1517)
		$owns:=([This:C1470._active].indexOf($lifecycle)=0) && (This:C1470._generation=$lifecycle.generation) && ([This:C1470._worker].indexOf($lifecycle.worker)=0)
	End if

Function _onExecute($worker : 4D:C1709.SystemWorker; $params : Object; $lifecycle : Object)

	This:C1470._onTerminal($worker; $params; $lifecycle; "onResponse")

Function _onFailure($worker : 4D:C1709.SystemWorker; $params : Object; $lifecycle : Object)

	This:C1470._onTerminal($worker; $params; $lifecycle; "onError")

Function _onTerminal($worker : 4D:C1709.SystemWorker; $params : Object; $lifecycle : Object; $event : Text)

	If ($lifecycle=Null:C1517)
		$lifecycle:=This:C1470._lifecycle($worker)
	End if
	If (Not:C34(This:C1470._owns($lifecycle)))
		return
	End if
	If ([$lifecycle.worker].indexOf($worker)#0)
		return
	End if
	If ($lifecycle.terminal) || ($lifecycle.terminated)
		return
	End if
	$lifecycle.terminal:=True:C214
	$lifecycle.notifying:=True:C214
	$params.context:=$lifecycle.context
	var $callback : 4D:C1709.Function
	$callback:=$lifecycle.handlers[$event]
	If (OB Instance of:C1731($callback; 4D:C1709.Function))
		$callback.call(This:C1470; $worker; $params)
	End if
	$lifecycle.notifying:=False:C215

	If (This:C1470._owns($lifecycle))
		If (This:C1470._commands.length=0)
			This:C1470._abort()
		End if
	End if

Function _options()->$options : Object

	$options:={controller: This:C1470; timeout: This:C1470.timeout; dataType: This:C1470.dataType; encoding: This:C1470.encoding; variables: This:C1470.variables; currentDirectory: This:C1470.currentDirectory; hideWindow: This:C1470.hideWindow}
	$options.handlers:={onResponse: This:C1470.onResponse; onTerminate: This:C1470.onTerminate; onData: This:C1470.onData; onDataError: This:C1470.onDataError; onError: This:C1470.onError}
	If (This:C1470._worker#Null:C1517)
		$options.handlers.onResponse:=This:C1470._onResponse
		$options.handlers.onTerminate:=This:C1470._onTerminate
	End if
	$options.lifecycle:={handlers: $options.handlers; terminal: False:C215; terminated: False:C215; notifying: False:C215}
	$options.onResponse:=Formula:C1597(This:C1470.controller._onInitialEvent(This:C1470; $1; $2; "onResponse"))
	$options.onTerminate:=Formula:C1597(This:C1470.controller._onInitialEvent(This:C1470; $1; $2; "onTerminate"))
	$options.onData:=Formula:C1597(This:C1470.controller._onInitialEvent(This:C1470; $1; $2; "onData"))
	$options.onDataError:=Formula:C1597(This:C1470.controller._onInitialEvent(This:C1470; $1; $2; "onDataError"))
	$options.onError:=Formula:C1597(This:C1470.controller._onInitialEvent(This:C1470; $1; $2; "onError"))

Function _execute($commands : Collection; $messages : Collection; $contexts : Collection)

	var $worker : 4D:C1709.SystemWorker
	var $options : Object
	$options:=This:C1470._options()
	If ($commands#Null:C1517)
		// Stage only an empty idle submission; constructor errors propagate without changing its queues or handlers.
		$worker:=4D:C1709.SystemWorker.new($commands[0]; $options)
	Else
		$worker:=4D:C1709.SystemWorker.new(This:C1470._commands[0]; $options)
	End if
	If ($worker=Null:C1517)
		// A caller's installed error handler may resume after the native rejection.
		return
	End if
	This:C1470._accept($worker; $options.lifecycle; $commands; $messages; $contexts)
	
	var $message : Variant
	$message:=This:C1470._messages.shift()
	
	var $vt : Integer
	$vt:=Value type:C1509($message)
	
	If ($vt=Is object:K8:27) && (OB Instance of:C1731($message; 4D:C1709.Blob))
		$vt:=Is BLOB:K8:12
	End if 
	
	Case of 
		: ($vt=Is null:K8:31)
			//
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

Function _accept($worker : 4D:C1709.SystemWorker; $lifecycle : Object; $commands : Collection; $messages : Collection; $contexts : Collection)

	If (This:C1470._worker=Null:C1517)
		This:C1470._onResponse:=This:C1470.onResponse
		This:C1470.onResponse:=This:C1470._onExecute
		This:C1470._onTerminate:=This:C1470.onTerminate
		This:C1470.onTerminate:=This:C1470._onComplete
	End if
	If ($commands#Null:C1517)
		This:C1470._commands.combine($commands)
		This:C1470._messages.combine($messages)
		This:C1470._contexts.combine($contexts)
	End if
	This:C1470._commands.shift()
	This:C1470._complete:=False:C215
	This:C1470._worker:=$worker
	This:C1470._generation+=1
	$lifecycle.generation:=This:C1470._generation
	$lifecycle.worker:=$worker
	$lifecycle.context:=This:C1470._contexts.shift()
	This:C1470.SYSTEM_WORKER_CONTEXT[String:C10($worker.pid)]:=$lifecycle.context
	This:C1470._lifecycles.push($lifecycle)
	This:C1470._active:=$lifecycle

Function _onInitialEvent($options : Object; $worker : 4D:C1709.SystemWorker; $params : Object; $event : Text)

	Case of
		: ($event="onResponse")
			This:C1470._onExecute($worker; $params; $options.lifecycle)
		: ($event="onError")
			This:C1470._onFailure($worker; $params; $options.lifecycle)
		: ($event="onTerminate")
			This:C1470._onComplete($worker; $params; $options.lifecycle)
		Else
			var $callback : 4D:C1709.Function
			$callback:=$options.handlers[$event]
			If (OB Instance of:C1731($callback; 4D:C1709.Function))
				$callback.call(This:C1470; $worker; $params)
			End if
	End case

Function _onComplete($worker : 4D:C1709.SystemWorker; $params : Object; $lifecycle : Object)

	If ($lifecycle=Null:C1517)
		$lifecycle:=This:C1470._lifecycle($worker)
	End if
	If ($lifecycle=Null:C1517)
		return
	End if
	If ([$lifecycle.worker].indexOf($worker)#0)
		return
	End if
	var $index : Integer
	$index:=This:C1470._lifecycles.indexOf($lifecycle)
	If ($index=-1) || ($lifecycle.terminated)
		return
	End if
	$lifecycle.terminated:=True:C214
	This:C1470._lifecycles.remove($index)
	If (This:C1470._owns($lifecycle)) && (($lifecycle.notifying) || (Not:C34($lifecycle.terminal)))
		// An interrupted notification never authorizes another launch.
		This:C1470.abortQueue()
	End if
	var $callback : 4D:C1709.Function
	$callback:=$lifecycle.handlers.onTerminate
	$lifecycle.notifying:=True:C214
	If (OB Instance of:C1731($callback; 4D:C1709.Function))
		$callback.call(This:C1470; $worker; $params)
	End if
	$lifecycle.notifying:=False:C215

	// Termination exposes the native exit status; user code decides before dispatch.
	If (This:C1470._owns($lifecycle))
		This:C1470._terminate()
		If (This:C1470._commands.length=0)
			This:C1470._abort()
		Else
			This:C1470._execute()
		End if
	End if

Function _abort()
	
	This:C1470.abortQueue()
	
Function _terminate()
	
	If (This:C1470._worker#Null:C1517)
		This:C1470.onResponse:=This:C1470._onResponse
		This:C1470.onTerminate:=This:C1470._onTerminate
	End if
	This:C1470._generation+=1
	This:C1470._active:=Null:C1517
	This:C1470._worker:=Null:C1517