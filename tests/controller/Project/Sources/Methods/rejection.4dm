var $path : Text
var $parameter : Integer
$parameter:=Get database parameter(User param value; $path)
var $done : Object
$done:=New shared object("complete"; False; "workerNumber"; 0)
var $started; $ticks : Integer
$started:=Milliseconds
$ticks:=0
CALL WORKER("controller-rejection-"+Generate UUID; "rejectionWorker"; "start"; $path; $done)
// Keep the headless driver alive; callbacks belong to the separate persistent worker.
Repeat
	DELAY PROCESS(Current process; 6)
	$ticks+=1
Until ($done.complete || ((Milliseconds-$started)>20000) || ($ticks>200))
If (Not($done.complete))
	File($path+".driver-timeout.json").setText(JSON Stringify({driverTimedOut: True}))
	If ($done.workerNumber#0)
		KILL WORKER($done.workerNumber)
	End if
End if
QUIT 4D
