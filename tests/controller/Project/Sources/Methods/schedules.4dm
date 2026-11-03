ON ERR CALL("probeError")
var $path : Text
var $parameter : Integer
$parameter:=Get database parameter(User param value; $path)
var $report : Object
$report:={checks: []; errors: []; traces: []; complete: False; compiledMode: Is compiled mode}
File($path).setText(JSON Stringify($report))
var $a; $b : 4D.SystemWorker
$a:=4D.SystemWorker.new("/usr/bin/true")
$a.wait(2)
$b:=4D.SystemWorker.new("/usr/bin/true")
$b.wait(2)
var $CLI : cs._CLI
$CLI:=cs._CLI.new()
var $controller : cs.Schedule
$controller:=cs.Schedule.new($CLI; [$a; $b])
$controller.onResponse:=Formula($report.traces.push({name: "response"; receiver: This=$controller; pid: $1.pid; context: $2.context}))
$controller.onTerminate:=Formula($report.traces.push({name: "termination"; receiver: This=$controller; pid: $1.pid}))
$controller.execute(["a"; "b"]; ["message-a"; "message-b"]; ["context-a"; "context-b"])
$controller._onExecute($a; {type: "response"})
scheduleCheck(($controller.worker=$b) && ($controller.launches=2) && Not($controller.complete); "response-dispatch"; $report; "regression")
$controller._onComplete($a; {type: "termination"})
scheduleCheck($controller.worker=$b; "old-termination"; $report; "regression")
scheduleCheck(($controller.onResponse=$controller._onExecute) && ($controller.onTerminate=$controller._onComplete); "old-handler-ownership"; $report; "regression")
$controller._onExecute($b; {type: "response"})
$controller._onComplete($b; {type: "termination"})
scheduleCheck(($controller.worker=Null) && $controller.complete; "final-release"; $report; "regression")
scheduleCheck(($report.traces.length=4) && $report.traces.every(Formula($1.value.receiver)) && ($report.traces[0].name="response") && ($report.traces[1].name="termination") && ($report.traces[2].name="response") && ($report.traces[3].name="termination") && ($report.traces[0].pid=$a.pid) && ($report.traces[1].pid=$a.pid) && ($report.traces[2].pid=$b.pid) && ($report.traces[3].pid=$b.pid); "callbacks"; $report; "regression")
scheduleCheck(($report.traces[0].context="context-a") && ($report.traces[2].context="context-b"); "context"; $report; "regression")
scheduleCheck(($controller.onResponse=$controller._onResponse) && ($controller.onTerminate=$controller._onTerminate); "handler-restoration"; $report; "regression")
$controller.pool.push($a)
$controller.execute("recovery"; Null; "context-recovery")
scheduleCheck(($controller.worker=$a) && ($controller.launches=3); "reuse"; $report; "regression")
$controller._onExecute($a; {type: "response"})
$controller._onComplete($a; {type: "termination"})

$controller:=cs.Schedule.new($CLI; [$a; $b])
$controller.execute(["failed"; "pending"]; ["failed-message"; "pending-message"]; ["failed-context"; "pending-context"])
$controller["onError"].call($controller; $a; {type: "error"})
$controller._onComplete($a; {type: "termination"})
scheduleCheck(($controller.worker=$a) && Not($controller.complete) && ($controller.commands.length=1); "no-response-retention"; $report; "candidate")
scheduleCheck(($controller._messages.length=1) && ($controller._contexts.length=1); "pending-parallel-queues"; $report; "candidate")
$controller.execute("later"; "later-message"; "later-context")
scheduleCheck(($controller.launches=1) && ($controller.commands.length=2); "stranded-execute"; $report; "candidate")
$controller.terminate()
scheduleCheck(($controller.worker=Null) && ($controller.commands.length=0) && $controller.complete; "explicit-abort"; $report; "regression")
scheduleCheck(($controller._messages.length=2) && ($controller._contexts.length=2); "abort-parallel-queues"; $report; "candidate")

$controller:=cs.Schedule.new($CLI; [$a; $b])
$controller.execute(["a"; "b"]; [Null; Null]; ["a"; "b"])
$controller._onExecute($a; {type: "response"})
$controller._onExecute($b; {type: "response"})
$controller._onComplete($a; {type: "termination"})
scheduleCheck($controller.worker=Null; "very-late-termination"; $report; "candidate")
var $duplicate : Object
$duplicate:={calls: []}
$controller._onTerminate:=Formula($duplicate.calls.push($1.pid))
$controller._onComplete($a; {type: "termination"})
$controller._onComplete($a; {type: "termination"})
scheduleCheck($duplicate.calls.length=2; "duplicate-termination"; $report; "candidate")

var $native : cs._CLI_Controller
var $command : Text
var $kind : Text
For each ($command; ["/usr/bin/true"; "/usr/bin/false"; "/bin/sleep 2"])
	Case of
		: ($command="/usr/bin/true")
			$kind:="true"
		: ($command="/usr/bin/false")
			$kind:="false"
		Else
			$kind:="timeout"
	End case
	$native:=cs._CLI_Controller.new($CLI)
	$native.timeout:=0.1
	$native.execute([$command; "/usr/bin/true"]; [Null; Null]; ["first"; "second"])
	$a:=$native.worker
	$a.wait(3)
	If ($native.worker#Null)
		$native.worker.wait(3)
	End if
	scheduleCheck(($native.worker=Null) && $native.complete && ($native.commands.length=0); "native-"+$kind+"-drain"; $report; "regression")
	$native.execute("/usr/bin/true")
	$b:=$native.worker
	$b.wait(3)
	scheduleCheck(($native.worker=Null) && $native.complete && ($a#$b); "native-"+$kind+"-reuse"; $report; "regression")
	If ($native.worker#Null)
		$native.terminate()
	End if
End for each
$report.complete:=True
File($path).setText(JSON Stringify($report))
QUIT 4D
