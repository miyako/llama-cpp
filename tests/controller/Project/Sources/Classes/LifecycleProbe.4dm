property path; phase : Text
property done; report; caseReport; old; simulatedEvent : Object
property controller : cs._CLI_Controller
property schedule : cs.Schedule
property workers; identities : Collection
property started; ticks; caseIndex; windowStarted; lateEvents : Integer
property marker : 4D.File
property simulatedAbort : Boolean

Class constructor($path : Text; $done : Object)
	This.path:=$path
	This.done:=$done
	This.started:=Milliseconds
	This.ticks:=0
	This.caseIndex:=0
	This.workers:=[]
	This.identities:=[]
	This.report:={checks: []; errors: []; cases: []; turns: []; simulated: []; complete: False; compiledMode: Is compiled mode; ownerProcess: rejectionProcess; acceptedNativeErrorWithoutResponseReproduced: False}
	var $build : Integer
	This.report.version:=Application version($build; *)
	This.report.build:=$build
	If (Not(This.report.ownerProcess.available))
		This.report.errors.push("owner-identity-unavailable")
		return
	End if
	This.marker:=File($path).parent.file("dependent-sideeffect")
	var $worker : 4D.SystemWorker
	var $i : Integer
	For ($i; 1; 2)
		$worker:=4D.SystemWorker.new("/usr/bin/true")
		$worker.wait(2)
		This.identities.push($worker)
		This.workers.push($worker)
	End for

Function start()
	This.phase:="synthetic-continue"
	This.schedule:=cs.Schedule.new(cs._CLI.new(); [This.identities[0]; This.identities[1]])
	This.schedule["onError"]:=Formula(lifecycleProbe.simulated(This; $1; $2))
	This.schedule.execute(["a"; "b"]; ["message-a"; "message-b"]; ["context-a"; "context-b"])
	This.old:=This.schedule._active
	This.simulatedEvent:={type: "error"; errors: [{errCode: 123; componentSignature: "synthetic"}]}

Function simulated($receiver : Object; $worker : 4D.SystemWorker; $event : Object)
	This.report.simulated.push({receiver: sameReference($receiver; This.schedule); worker: sameReference($worker; This.identities[0]); event: sameReference($event; This.simulatedEvent); context: $event.context; launches: This.schedule.launches; process: rejectionProcess})
	If (This.simulatedAbort)
		$receiver.abortQueue()
	End if

Function next()
	This.caseIndex+=1
	This.controller:=cs._CLI_Controller.new(cs._CLI.new())
	This.controller.timeout:=2
	This.controller.onResponse:=Formula(lifecycleProbe.response(This; $1; $2))
	This.controller.onTerminate:=Formula(lifecycleProbe.terminated(This; $1; $2))
	This.caseReport:={name: ""; kind: "native-control"; events: []; callbackErrors: []; returned: 0}
	This.report.cases.push(This.caseReport)
	var $command; $dependent : Text
	$command:="/usr/bin/true"
	$dependent:="/usr/bin/touch \""+This.marker.platformPath+"\""
	Case of
		: (This.caseIndex=1)
			This.phase:="nonzero-abort"
			$command:="/usr/bin/false"
		: (This.caseIndex=2)
			This.phase:="no-handler"
			This.controller.onResponse:=Null
			$dependent:="/usr/bin/true"
		: (This.caseIndex=3)
			This.phase:="abort-active"
			$command:="/bin/sleep 0.4"
		: (This.caseIndex=4)
			This.phase:="callback-resume"
			$dependent:="/usr/bin/true"
			ON ERR CALL("lifecycleResume"; ek local)
	End case
	This.caseReport.name:=This.phase
	This.controller.execute([$command; $dependent]; [Null; Null]; ["first"; "second"])
	If (This.controller.worker#Null)
		This.workers.push(This.controller.worker)
	End if
	If (This.phase="abort-active")
		var $worker : 4D.SystemWorker
		$worker:=This.controller.worker
		This.controller.abortQueue()
		scheduleCheck(Not($worker.terminated) && sameReference(This.controller.worker; $worker) && This.empty(); "abort-does-not-terminate"; This.report; "regression")
	End if

Function response($receiver : Object; $worker : 4D.SystemWorker; $event : Object)
	This.record("response"; $receiver; $worker; $event)
	If (This.phase="callback-resume") && ($event.context="first")
		var $rejected : 4D.SystemWorker
		$rejected:=4D.SystemWorker.new("/nonexistent/controller-callback-"+Generate UUID)
		This.caseReport.returned+=1
	End if

Function terminated($receiver : Object; $worker : 4D.SystemWorker; $event : Object)->$result : Boolean
	This.record("termination"; $receiver; $worker; $event)
	If (This.phase="nonzero-abort")
		If ([Is real; Is integer].includes(Value type($worker.exitCode)))
			If ($worker.exitCode#0)
				$receiver.abortQueue()
			End if
		Else
			This.report.errors.push("native-exit-status-unavailable-at-termination")
		End if
	End if
	$result:=False

Function record($name : Text; $receiver : Object; $worker : 4D.SystemWorker; $event : Object)
	If (This.workers.indexOf($worker)=-1)
		This.workers.push($worker)
	End if
	var $activePID : Integer
	$activePID:=0
	If ($receiver.worker#Null)
		$activePID:=$receiver.worker.pid
	End if
	This.caseReport.events.push({name: $name; receiver: sameReference($receiver; This.controller); pid: $worker.pid; type: $event.type; context: $event.context; exitCode: $worker.exitCode; activePID: $activePID; process: rejectionProcess; handler: Method called on error(ek local); event: OB Copy($event)})

Function empty()->$empty : Boolean
	$empty:=(This.controller.commands.length=0) && (This.controller._messages.length=0) && (This.controller._contexts.length=0)

Function tick()
	This.ticks+=1
	This.report.turns.push({turn: This.ticks; phase: This.phase; process: rejectionProcess})
	If ((Milliseconds-This.started)>14000) || (This.ticks>140)
		If (This.phase#"cleanup")
			This.report.errors.push("bounded-worker-timeout")
			This.finish(False)
		End if
	End if
	Case of
		: (This.phase="synthetic-continue")
			This.schedule._onInitialEvent({lifecycle: This.old}; This.identities[0]; This.simulatedEvent; "onError")
			scheduleCheck((This.schedule.launches=1) && sameReference(This.schedule.worker; This.identities[0]); "persistent-synthetic-error-awaits-termination"; This.report; "regression")
			This.phase:="synthetic-finish"
		: (This.phase="synthetic-finish")
			This.schedule._onComplete(This.identities[0]; {type: "termination"}; This.old)
			scheduleCheck((This.schedule.launches=2) && sameReference(This.schedule.worker; This.identities[1]); "persistent-synthetic-error-continue"; This.report; "regression")
			This.schedule._onComplete(This.identities[0]; {type: "termination"}; This.old)
			scheduleCheck(sameReference(This.schedule.worker; This.identities[1]); "persistent-synthetic-old-termination"; This.report; "regression")
			This.schedule._onExecute(This.identities[1]; {type: "response"})
			This.schedule._onComplete(This.identities[1]; {type: "termination"})
			scheduleCheck((This.schedule.worker=Null) && This.schedule.complete; "persistent-synthetic-final-release"; This.report; "regression")
			This.schedule:=cs.Schedule.new(cs._CLI.new(); [This.identities[0]; This.identities[1]])
			This.schedule["onError"]:=Formula(lifecycleProbe.simulated(This; $1; $2))
			This.schedule.execute(["a"; "b"]; ["message-a"; "message-b"]; ["context-a"; "context-b"])
			This.simulatedAbort:=True
			This.phase:="synthetic-abort"
		: (This.phase="synthetic-abort")
			This.schedule._onFailure(This.identities[0]; This.simulatedEvent)
			scheduleCheck((This.schedule.launches=1) && (This.schedule.commands.length=0) && (This.schedule._messages.length=0) && (This.schedule._contexts.length=0); "persistent-synthetic-error-abort"; This.report; "regression")
			This.schedule._onComplete(This.identities[0]; {type: "termination"})
			scheduleCheck((This.report.simulated.length=2) && This.report.simulated.every(Formula($1.value.receiver && $1.value.worker && $1.value.event && ($1.value.launches=1) && ($1.value.context="context-a"))); "persistent-synthetic-callbacks"; This.report; "regression")
			This.schedule:=cs.Schedule.new(cs._CLI.new(); [This.identities[0]; This.identities[1]])
			This.schedule.execute(["a"; "b"]; ["message-a"; "message-b"]; ["context-a"; "context-b"])
			// Manual interrupted-notification state, not an actual callback ABORT.
			This.schedule._active.terminal:=True
			This.schedule._active.notifying:=True
			This.schedule._onComplete(This.identities[0]; {type: "termination"})
			scheduleCheck((This.schedule.launches=1) && (This.schedule.worker=Null) && This.schedule.complete && (This.schedule.commands.length=0) && (This.schedule._messages.length=0) && (This.schedule._contexts.length=0); "persistent-synthetic-interrupted-notification"; This.report; "regression")
			This.next()
		: (This.phase="late")
			If ((Milliseconds-This.windowStarted)>=500)
				var $count : Integer
				$count:=0
				var $case : Object
				For each ($case; This.report.cases)
					$count+=$case.events.length
				End for each
				scheduleCheck(($count=This.lateEvents) && Not(This.marker.exists); "persistent-late-sideeffects"; This.report; "regression")
				This.finish(True)
			End if
		: (This.phase="cleanup")
			If ((Milliseconds-This.windowStarted)>=500)
				var $clean : Boolean
				$clean:=True
				var $owned : 4D.SystemWorker
				This.report.cleanup:=[]
				For each ($owned; This.workers)
					$clean:=$clean && $owned.terminated
					This.report.cleanup.push({pid: $owned.pid; terminated: $owned.terminated})
				End for each
				scheduleCheck($clean; "persistent-native-cleanup"; This.report; "regression")
				This.report.sideEffectObserved:=This.marker.exists
				This.report.reportProcess:=rejectionProcess
				scheduleCheck((This.report.turns.length>5) && (This.report.ownerProcess.ID=This.report.reportProcess.ID) && (This.report.ownerProcess.number#1); "persistent-lifecycle-owner"; This.report; "regression")
				This.report.complete:=True
				File(This.path).setText(JSON Stringify(This.report))
				Use (This.done)
					This.done.complete:=True
				End use
				KILL WORKER(Current process)
			End if
		Else
			If (This.controller.worker=Null) && This.controller.complete
				var $valid : Boolean
				$valid:=This.empty() && (This.controller._lifecycles.length=0)
				Case of
					: (This.phase="nonzero-abort")
						$valid:=$valid && (This.caseReport.events.length=2) && (This.caseReport.events[1].exitCode=1) && Not(This.marker.exists)
						scheduleCheck($valid; "native-nonzero-abort-before-sideeffect"; This.report; "regression")
					: (This.phase="no-handler")
						$valid:=$valid && (This.caseReport.events.length=2) && This.caseReport.events.every(Formula($1.value.name="termination"))
						scheduleCheck($valid; "native-no-handler-continues"; This.report; "regression")
					: (This.phase="abort-active")
						$valid:=$valid && (This.caseReport.events.length=2) && Not(This.marker.exists)
						scheduleCheck($valid; "native-abort-preserves-callbacks"; This.report; "regression")
					: (This.phase="callback-resume")
						If (File(This.path+".callback-resume.json").exists)
							This.caseReport.callbackErrors.push(JSON Parse(File(This.path+".callback-resume.json").getText()))
						End if
						$valid:=$valid && (This.caseReport.events.length=4) && (This.caseReport.callbackErrors.length=1) && (This.caseReport.returned=1)
						scheduleCheck($valid; "callback-resume-continues"; This.report; "regression")
						scheduleCheck(Method called on error(ek local)="lifecycleResume"; "resume-handler-unchanged"; This.report; "regression")
						ON ERR CALL("probeError"; ek local)
				End case
				If (This.caseIndex<4)
					This.next()
				Else
					This.lateEvents:=10
					This.phase:="late"
					This.windowStarted:=Milliseconds
				End if
			End if
	End case
	File(This.path).setText(JSON Stringify(This.report))

Function finish($success : Boolean)
	ON ERR CALL("probeError"; ek local)
	If (Not($success))
		This.report.errors.push("lifecycle-did-not-complete")
	End if
	This.phase:="cleanup"
	This.windowStarted:=Milliseconds
	If (This.controller#Null)
		This.controller.terminate()
	End if
	var $owned : 4D.SystemWorker
	For each ($owned; This.workers)
		If (Not($owned.terminated))
			$owned.terminate()
		End if
	End for each
