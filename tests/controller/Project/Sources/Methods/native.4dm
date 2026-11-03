ON ERR CALL("probeError")
var $path : Text
var $parameter : Integer
$parameter:=Get database parameter(User param value; $path)
var $report : Object
$report:={cases: []; checks: []; errors: []; complete: False; compiledMode: Is compiled mode}
File($path).setText(JSON Stringify($report))
var $case : Object
For each ($case; [{name: "success"; command: "/usr/bin/true"; timeout: 2}; {name: "nonzero"; command: "/usr/bin/false"; timeout: 2}; {name: "signal-attempt"; command: "/bin/sh -c \"kill -TERM $$\""; timeout: 2}; {name: "timeout"; command: "/bin/sleep 2"; timeout: 0.1}; {name: "missing"; command: "/nonexistent/controller-probe"; timeout: 2}])
	var $options : cs.Probe
	$options:=cs.Probe.new($case.timeout)
	var $worker : 4D.SystemWorker
	$worker:=Null
	If ($case.name="missing")
		ON ERR CALL("rejectionError")
	End if
	$worker:=4D.SystemWorker.new($case.command; $options)
	ON ERR CALL("probeError")
	$case.accepted:=($worker#Null)
	If ($worker#Null)
		$worker.wait(3)
		$case.terminated:=$worker.terminated
		$case.pid:=$worker.pid
		$case.exitCode:=$worker.exitCode
		$case.errors:=$worker.errors
		If (Not($worker.terminated))
			$worker.terminate()
			$worker.wait(1)
		End if
	End if
	$case.events:=$options.events
	$report.cases.push($case)
	File($path).setText(JSON Stringify($report))
End for each
var $normal : Boolean
$normal:=True
For each ($case; $report.cases.slice(0; 4))
	$normal:=$normal && $case.accepted && $case.terminated && ($case.events.length=2)
	If ($case.events.length=2)
		$normal:=$normal && ($case.events[0].name="response") && ($case.events[1].name="termination")
	End if
End for each
scheduleCheck($normal; "native-events"; $report; "regression")
scheduleCheck(Not($report.cases[4].accepted) && ($report.cases[4].events.length=0); "synchronous-rejection"; $report; "regression")
$report.complete:=True
File($path).setText(JSON Stringify($report))
QUIT 4D
