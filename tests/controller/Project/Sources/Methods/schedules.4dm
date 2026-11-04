ON ERR CALL("probeError")
var $path : Text
var $parameter : Integer
$parameter:=Get database parameter(User param value; $path)
var $report : Object
$report:={checks: []; errors: []; traces: []; complete: False; compiledMode: Is compiled mode}
File($path).setText(JSON Stringify($report))
var $identity : Object
$identity:={}
scheduleCheck(sameReference($identity; $identity) && Not(sameReference($identity; {})); "reference-controls"; $report; "regression")
var $a; $b : 4D.SystemWorker
$a:=4D.SystemWorker.new("/usr/bin/true")
$a.wait(2)
$b:=4D.SystemWorker.new("/usr/bin/true")
$b.wait(2)
var $CLI : cs._CLI
$CLI:=cs._CLI.new()
var $controller : cs.Schedule
$controller:=cs.Schedule.new($CLI; [$a; $b])
$controller.onResponse:=Formula($report.traces.push({name: "response"; receiver: sameReference(This; $controller); pid: $1.pid; context: $2.context; launches: This.launches}))
$controller.onTerminate:=Formula($report.traces.push({name: "termination"; receiver: sameReference(This; $controller); pid: $1.pid; launches: This.launches}))
$controller.execute(["a"; "b"]; ["message-a"; "message-b"]; ["context-a"; "context-b"])
$controller._onExecute($a; {type: "response"})
scheduleCheck($report.traces[0].launches=1; "callback-before-dispatch"; $report; "regression")
scheduleCheck(sameReference($controller.worker; $a) && ($controller.launches=1) && Not($controller.complete); "response-defers-dispatch"; $report; "regression")
$controller._onComplete($a; {type: "termination"})
scheduleCheck($report.traces[1].launches=1; "termination-before-dispatch"; $report; "regression")
$controller._onComplete($a; {type: "termination"})
scheduleCheck(sameReference($controller.worker; $b); "old-termination"; $report; "regression")
scheduleCheck(sameReference($controller.onResponse; $controller._onExecute) && sameReference($controller.onTerminate; $controller._onComplete); "old-handler-ownership"; $report; "regression")
$controller._onExecute($b; {type: "response"})
$controller._onComplete($b; {type: "termination"})
scheduleCheck(($controller.worker=Null) && $controller.complete; "final-release"; $report; "regression")
scheduleCheck(($report.traces.length=4) && $report.traces.every(Formula($1.value.receiver)) && ($report.traces[0].name="response") && ($report.traces[1].name="termination") && ($report.traces[2].name="response") && ($report.traces[3].name="termination") && ($report.traces[0].pid=$a.pid) && ($report.traces[1].pid=$a.pid) && ($report.traces[2].pid=$b.pid) && ($report.traces[3].pid=$b.pid); "callbacks"; $report; "regression")
scheduleCheck(($report.traces[0].context="context-a") && ($report.traces[2].context="context-b"); "context"; $report; "regression")
scheduleCheck(sameReference($controller.onResponse; $controller._onResponse) && sameReference($controller.onTerminate; $controller._onTerminate); "handler-restoration"; $report; "regression")
$controller.pool.push($a)
$controller.execute("recovery"; Null; "context-recovery")
scheduleCheck(sameReference($controller.worker; $a) && ($controller.launches=3); "reuse"; $report; "regression")
$controller._onExecute($a; {type: "response"})
$controller._onComplete($a; {type: "termination"})

$controller:=cs.Schedule.new($CLI; [$a; $b])
$controller["onError"]:=Null
$controller.execute(["failed"; "pending"]; ["failed-message"; "pending-message"]; ["failed-context"; "pending-context"])
var $old : Object
$old:=$controller._active
$controller._onInitialEvent({lifecycle: $old}; $a; {type: "error"}; "onError")
scheduleCheck(sameReference($controller.worker; $a) && ($controller.launches=1); "error-awaits-termination"; $report; "regression")
$controller._onComplete($a; {type: "termination"})
scheduleCheck(sameReference($controller.worker; $b) && ($controller.launches=2); "error-default-continue"; $report; "regression")
scheduleCheck(($controller.commands.length=0) && ($controller._messages.length=0) && ($controller._contexts.length=0) && ($controller.SYSTEM_WORKER_CONTEXT[String($b.pid)]="pending-context"); "error-parallel-queues"; $report; "regression")
$controller._onComplete($a; {type: "termination"})
scheduleCheck(sameReference($controller.worker; $b) && Not($controller.complete); "error-old-termination"; $report; "regression")
$controller._onExecute($b; {type: "response"})
$controller._onComplete($b; {type: "termination"})
scheduleCheck(($controller.worker=Null) && $controller.complete; "error-final-release"; $report; "regression")
$controller.pool.push($a)
$controller.execute("later"; Null; "later-context")
scheduleCheck(($controller.launches=3) && sameReference($controller.worker; $a); "error-later-execute"; $report; "regression")
$controller._onComplete($a; {type: "termination"}; $old)
$controller._onExecute($a; {type: "response"}; $old)
$controller._onFailure($a; {type: "error"}; $old)
scheduleCheck(($controller.launches=3) && sameReference($controller.worker; $a) && Not($controller._active.terminal); "stale-generation"; $report; "regression")
$controller.terminate()
scheduleCheck(($controller.worker=Null) && ($controller.commands.length=0) && $controller.complete; "explicit-abort"; $report; "regression")
scheduleCheck(($controller._messages.length=0) && ($controller._contexts.length=0); "abort-parallel-queues"; $report; "regression")

$controller:=cs.Schedule.new($CLI; [$a; $b])
$controller.action:="restart"
$controller.onResponse:=$controller.observe
$controller.onTerminate:=Formula($report.traces.push({name: "late-termination"; pid: $1.pid}))
$controller.execute(["a"; "b"]; [Null; Null]; ["a"; "b"])
$old:=$controller._active
$controller._onExecute($a; {type: "response"})
$controller.action:=""
$controller._onExecute($b; {type: "response"})
$controller._onComplete($a; {type: "termination"})
scheduleCheck(sameReference($controller.worker; $b) && $controller.complete; "very-late-termination"; $report; "regression")
var $count : Integer
$count:=$report.traces.length
$controller._onComplete($a; {type: "termination"}; $old)
$controller._onComplete($a; {type: "termination"})
scheduleCheck($report.traces.length=$count; "duplicate-termination"; $report; "regression")
$controller._onComplete($b; {type: "termination"})
scheduleCheck(($controller.worker=Null) && ($controller._lifecycles.length=0); "lifecycle-release"; $report; "regression")

var $mode : Text
var $event : Object
For each ($mode; ["abort"; "enqueue"; "abort-enqueue"; "terminate"; "restart"; "continue"])
	$controller:=cs.Schedule.new($CLI; [$a; $b; $a])
	$controller.action:=$mode
	$controller.onResponse:=$controller.observe
	$controller.expectedWorker:=$a
	$event:={type: "response"; original: {}}
	$controller.expectedEvent:=$event
	$controller.execute(["a"; "b"]; ["message-a"; "message-b"]; ["context-a"; "context-b"])
	$old:=$controller._active
	$controller._onExecute($a; $event)
	scheduleCheck(($controller.observations.length=1) && ($controller.observations[0].launches=1) && $controller.observations[0].worker && $controller.observations[0].event && ($event.context="context-a"); "reentrant-"+$mode+"-callback"; $report; "regression")
	$controller._onComplete($a; {type: "termination"}; $old)
	Case of
		: ($mode="abort")
			scheduleCheck(($controller.launches=1) && ($controller.worker=Null) && ($controller.commands.length=0) && ($controller._messages.length=0) && ($controller._contexts.length=0) && $controller.complete; "callback-abort"; $report; "regression")
		: ($mode="enqueue")
			scheduleCheck(($controller.launches=2) && sameReference($controller.worker; $b) && ($controller.commands.length=1) && ($controller._messages[0]="message-c") && ($controller._contexts[0]="context-c"); "callback-enqueue"; $report; "regression")
		: ($mode="abort-enqueue")
			scheduleCheck(($controller.launches=2) && sameReference($controller.worker; $b) && ($controller.commands.length=0) && ($controller.SYSTEM_WORKER_CONTEXT[String($b.pid)]="replacement-context"); "callback-abort-enqueue"; $report; "regression")
		: ($mode="terminate")
			scheduleCheck(($controller.launches=1) && ($controller.worker=Null) && ($controller.commands.length=0) && ($controller._messages.length=0) && ($controller._contexts.length=0); "callback-terminate"; $report; "regression")
		: ($mode="restart")
			scheduleCheck(($controller.launches=2) && sameReference($controller.worker; $b) && ($controller.SYSTEM_WORKER_CONTEXT[String($b.pid)]="restart-context"); "callback-restart"; $report; "regression")
		: ($mode="continue")
			scheduleCheck(($controller.launches=2) && sameReference($controller.worker; $b); "false-return-ignored"; $report; "regression")
	End case
	$count:=$controller.launches
	$controller._onExecute($a; $event; $old)
	$controller._onFailure($a; {type: "error"}; $old)
	scheduleCheck(($controller.launches=$count) && ($controller.observations.length=1); "reentrant-"+$mode+"-duplicate"; $report; "regression")
	$controller.terminate()
End for each

$controller:=cs.Schedule.new($CLI; [$a; $b])
$controller.action:="abort"
$controller["onError"]:=$controller.observe
$controller.expectedWorker:=$a
$event:={type: "error"; errors: [{errCode: 123; componentSignature: "synthetic"}]}
$controller.expectedEvent:=$event
$controller.execute(["a"; "b"]; ["message-a"; "message-b"]; ["context-a"; "context-b"])
$controller._onFailure($a; $event)
scheduleCheck(($controller.launches=1) && ($controller.observations.length=1) && $controller.observations[0].worker && $controller.observations[0].event && ($event.context="context-a") && ($event.errors[0].errCode=123) && ($controller.commands.length=0) && ($controller._messages.length=0) && ($controller._contexts.length=0); "error-callback-abort"; $report; "regression")
$controller._onComplete($a; {type: "termination"})
scheduleCheck(($controller.worker=Null) && $controller.complete; "error-abort-termination"; $report; "regression")

var $failed : 4D.SystemWorker
$failed:=4D.SystemWorker.new("/usr/bin/false")
$failed.wait(2)
$controller:=cs.Schedule.new($CLI; [$failed; $a])
$controller.action:="abort-nonzero"
$controller.onResponse:=$controller.observe
$controller.execute(["nonzero"; "dependent"]; [Null; "discard"]; ["nonzero"; "discard"])
$controller._onExecute($failed; {type: "response"})
scheduleCheck(($failed.exitCode=1) && ($controller.launches=1) && ($controller.commands.length=0) && ($controller._messages.length=0) && ($controller._contexts.length=0); "nonzero-callback-abort"; $report; "regression")
$controller._onComplete($failed; {type: "termination"})

$controller:=cs.Schedule.new($CLI; [$a; $b])
$controller.execute("a")
$controller._onExecute($a; {type: "response"})
$controller.execute("after-response"; Null; "after-response")
scheduleCheck(($controller.launches=1) && sameReference($controller.worker; $a) && ($controller.commands.length=1); "enqueue-awaits-termination"; $report; "regression")
$controller._onComplete($a; {type: "termination"})
scheduleCheck(($controller.launches=2) && sameReference($controller.worker; $b); "enqueue-after-response-ownership"; $report; "regression")
$controller.terminate()

For each ($mode; ["abort"; "enqueue"; "abort-enqueue"; "terminate"; "restart"; "continue"])
	$controller:=cs.Schedule.new($CLI; [$a; $b])
	$controller.action:=$mode
	$controller.onTerminate:=$controller.observe
	$controller.expectedWorker:=$a
	$event:={type: "termination"; original: {}}
	$controller.expectedEvent:=$event
	$controller.execute(["a"; "b"]; ["message-a"; "message-b"]; ["context-a"; "context-b"])
	$old:=$controller._active
	$controller._onExecute($a; {type: "response"})
	$controller._onComplete($a; $event)
	scheduleCheck(($controller.observations.length=1) && ($controller.observations[0].launches=1) && $controller.observations[0].worker && $controller.observations[0].event; "termination-"+$mode+"-callback"; $report; "regression")
	Case of
		: ($mode="abort") || ($mode="terminate")
			scheduleCheck(($controller.launches=1) && ($controller.worker=Null) && ($controller.commands.length=0) && ($controller._messages.length=0) && ($controller._contexts.length=0); "termination-"+$mode+"-result"; $report; "regression")
		: ($mode="enqueue")
			scheduleCheck(($controller.launches=2) && sameReference($controller.worker; $b) && ($controller.commands.length=1) && ($controller._messages[0]="message-c") && ($controller._contexts[0]="context-c"); "termination-"+$mode+"-result"; $report; "regression")
		: ($mode="abort-enqueue")
			scheduleCheck(($controller.launches=2) && sameReference($controller.worker; $b) && ($controller.commands.length=0) && ($controller.SYSTEM_WORKER_CONTEXT[String($b.pid)]="replacement-context"); "termination-"+$mode+"-result"; $report; "regression")
		: ($mode="restart")
			scheduleCheck(($controller.launches=2) && sameReference($controller.worker; $b) && ($controller.SYSTEM_WORKER_CONTEXT[String($b.pid)]="restart-context"); "termination-"+$mode+"-result"; $report; "regression")
		: ($mode="continue")
			scheduleCheck(($controller.launches=2) && sameReference($controller.worker; $b); "termination-"+$mode+"-result"; $report; "regression")
	End case
	$count:=$controller.launches
	$controller._onComplete($a; $event; $old)
	$controller._onExecute($a; {type: "response"}; $old)
	$controller._onFailure($a; {type: "error"}; $old)
	scheduleCheck(($controller.launches=$count) && ($controller.observations.length=1); "termination-"+$mode+"-stale"; $report; "regression")
	$controller.terminate()
End for each

$controller:=cs.Schedule.new($CLI; [$a; $b])
$controller.onTerminate:=Null
$controller.execute(["a"; "b"]; [Null; Null]; [Null; Null])
$controller._onExecute($a; {type: "response"})
$controller._onComplete($a; {type: "termination"})
scheduleCheck(($controller.launches=2) && sameReference($controller.worker; $b); "no-termination-handler"; $report; "regression")
$controller.terminate()

$controller:=cs.Schedule.new($CLI; [$a; $b])
$controller.execute(["a"; "b"]; [Null; Null]; [Null; Null])
$old:=$controller._active
$controller._onExecute($b; {type: "response"}; $old)
$controller._onComplete($b; {type: "termination"}; $old)
scheduleCheck(($controller.launches=1) && Not($old.terminal) && Not($old.terminated); "worker-argument-ownership"; $report; "regression")
$controller.terminate()

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
	scheduleCheck(($native.worker=Null) && $native.complete && Not(sameReference($a; $b)); "native-"+$kind+"-reuse"; $report; "regression")
	If ($native.worker#Null)
		$native.terminate()
	End if
End for each
$report.complete:=True
File($path).setText(JSON Stringify($report))
QUIT 4D
