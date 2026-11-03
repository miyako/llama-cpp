Class extends _CLI_Controller

property pool : Collection
property launches : Integer

Class constructor($CLI : cs._CLI; $pool : Collection)
	Super($CLI)
	This.pool:=$pool
	This.launches:=0

Function _execute($commands : Collection; $messages : Collection; $contexts : Collection)
	If ($commands#Null)
		This._onResponse:=This.onResponse
		This.onResponse:=This._onExecute
		This._onTerminate:=This.onTerminate
		This.onTerminate:=This._onComplete
		This._commands.combine($commands)
		This._messages.combine($messages)
		This._contexts.combine($contexts)
	End if
	This._complete:=False
	This._commands.shift()
	This._worker:=This.pool.shift()
	This.SYSTEM_WORKER_CONTEXT[String(This._worker.pid)]:=This._contexts.shift()
	This._messages.shift()
	This.launches+=1
