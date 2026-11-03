property events : Collection
property timeout : Real

Class constructor($timeout : Real)
	This.events:=[]
	This.timeout:=$timeout

Function record($name : Text; $worker : 4D.SystemWorker; $event : Object)
	This.events.push({name: $name; type: $event.type; pid: $worker.pid; exitCode: $worker.exitCode; errors: $worker.errors; terminated: $worker.terminated})

Function onResponse($worker : 4D.SystemWorker; $event : Object)
	This.record("response"; $worker; $event)

Function onError($worker : 4D.SystemWorker; $event : Object)
	This.record("error"; $worker; $event)

Function onTerminate($worker : 4D.SystemWorker; $event : Object)
	This.record("termination"; $worker; $event)
