#DECLARE($action : Text; $path : Text; $done : Object)
var lifecycleProbe : cs.LifecycleProbe
If ($action="start")
	ON ERR CALL("probeError"; ek local)
	Use ($done)
		$done.workerNumber:=Current process
	End use
	lifecycleProbe:=cs.LifecycleProbe.new($path; $done)
	If (lifecycleProbe.report.errors.length=0)
		lifecycleProbe.start()
	Else
		lifecycleProbe.finish(False)
	End if
Else
	lifecycleProbe.tick()
End if
If (Not(lifecycleProbe.report.complete))
	CALL WORKER(Current process; "lifecycleWorker"; "tick"; $path; $done)
	If ($action#"start")
		DELAY PROCESS(Current process; 6)
	End if
End if
