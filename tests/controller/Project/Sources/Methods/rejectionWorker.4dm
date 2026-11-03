#DECLARE($action : Text; $path : Text; $done : Object)
var rejectionProbe : cs.RejectionProbe
ON ERR CALL("probeError"; ek local)
If ($action="start")
	Use ($done)
		$done.workerNumber:=Current process
	End use
	rejectionProbe:=cs.RejectionProbe.new($path; $done)
	If (rejectionProbe.report.errors.length=0)
		rejectionProbe.advance()
	Else
		rejectionProbe.finish(False)
	End if
Else
	rejectionProbe.tick()
End if
If (Not(rejectionProbe.report.complete))
	If ($action#"start")
		DELAY PROCESS(Current process; 6)
	End if
	CALL WORKER(Current process; "rejectionWorker"; "tick"; $path; $done)
End if
