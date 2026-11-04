Class extends _CLI_Controller

property pool : Collection
property launches : Integer
property observations : Collection
property action : Text
property expectedWorker : 4D.SystemWorker
property expectedEvent : Object

Class constructor($CLI : cs._CLI; $pool : Collection)
	Super($CLI)
	This.pool:=$pool
	This.launches:=0
	This.observations:=[]
	This.action:=""

Function observe($worker : 4D.SystemWorker; $event : Object)->$result : Boolean
	This.observations.push({launches: This.launches; worker: sameReference($worker; This.expectedWorker); event: sameReference($event; This.expectedEvent); context: $event.context; type: $event.type})
	Case of
		: (This.action="abort")
			This.abortQueue()
		: (This.action="abort-nonzero")
			If ($worker.exitCode#0)
				This.abortQueue()
			End if
		: (This.action="enqueue")
			This.execute("c"; "message-c"; "context-c")
		: (This.action="abort-enqueue")
			This.abortQueue()
			This.execute("replacement"; "replacement-message"; "replacement-context")
		: (This.action="terminate")
			This.terminate()
		: (This.action="restart")
			This.terminate()
			This.execute("restart"; Null; "restart-context")
	End case
	$result:=False

Function _execute($commands : Collection; $messages : Collection; $contexts : Collection)
	var $options : Object
	$options:=This._options()
	This._accept(This.pool.shift(); $options.lifecycle; $commands; $messages; $contexts)
	This._messages.shift()
	This.launches+=1
