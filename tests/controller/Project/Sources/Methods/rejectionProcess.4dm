#DECLARE()->$process : Object
var $activity; $candidate : Object
$activity:=Get process activity:C1495(Processes only)
For each ($candidate; $activity.processes)
	If ($candidate.number=Current process)
		$process:=OB Copy($candidate)
		return
	End if
End for each
ASSERT(False; "Current diagnostic worker missing from process activity")
