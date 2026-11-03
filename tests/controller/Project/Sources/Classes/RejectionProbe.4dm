property report; done : Object
property controller : cs._CLI_Controller
property responseHandler; terminationHandler : 4D.Function
property workers : Collection
property path; phase; label : Text
property started; caseIndex; eventStart; expectedEvents; windowStarted; ticks : Integer
property constructing; finishingSuccess : Boolean

Class constructor($path : Text; $done : Object)
	This.path:=$path
	This.done:=$done
	This.started:=Milliseconds
	This.workers:=[]
	This.caseIndex:=0
	This.ticks:=0
	var $build : Integer
	var $version : Text
	$version:=Application version($build; *)
	This.report:={checks: []; errors: []; events: []; rejections: []; states: []; turns: []; complete: False; compiledMode: Is compiled mode; version: $version; build: $build; ownerProcess: Process info(Current process)}
	This.controller:=cs._CLI_Controller.new(cs._CLI.new())
	This.controller.timeout:=2
	This.controller.SYSTEM_WORKER_CONTEXT["existing"]:={retained: True}
	This.responseHandler:=Formula(rejectionProbe.record("response"; This; $1; $2))
	This.terminationHandler:=Formula(rejectionProbe.record("termination"; This; $1; $2))
	This.controller.onResponse:=This.responseHandler
	This.controller.onTerminate:=This.terminationHandler
	This.controller["onError"]:=Formula(rejectionProbe.record("error"; This; $1; $2))

Function reject($batch : Boolean; $label : Text)->$safe : Boolean
	var $map; $handler : Text
	var $savedResponse; $savedTermination : 4D.Function
	var $before; $events : Integer
	$map:=JSON Stringify(This.controller.SYSTEM_WORKER_CONTEXT)
	$savedResponse:=This.controller._onResponse
	$savedTermination:=This.controller._onTerminate
	$before:=This.report.rejections.length
	$events:=This.report.events.length
	$handler:=Method called on error(ek local)
	ON ERR CALL("rejectionCapture"; ek local)
	This.constructing:=True
	If ($batch)
		This.controller.execute(["/nonexistent/controller-rejection-"+Generate UUID; "/usr/bin/true"]; ["discard-first"; "discard-second"]; ["failed"; "discarded"])
	Else
		This.controller.execute("/nonexistent/controller-rejection-"+Generate UUID; "discard"; "failed")
	End if
	This.constructing:=False
	ON ERR CALL($handler; ek local)
	var $original : Boolean
	$original:=This.report.rejections.length=($before+1)
	If ($original)
		var $stack : Collection
		$stack:=This.report.rejections[$before].errors
		$original:=$stack.length=1
		If ($original)
			$original:=($stack[0].errCode=2) && ($stack[0].componentSignature="POSX")
		End if
	End if
	scheduleCheck($original; $label+"-error"; This.report; "regression")
	$safe:=This.idle() && sameReference(This.controller._onResponse; $savedResponse) && sameReference(This.controller._onTerminate; $savedTermination) && ($map=JSON Stringify(This.controller.SYSTEM_WORKER_CONTEXT)) && (This.report.events.length=$events)
	This.report.states.push({label: $label; workerNull: This.controller.worker=Null; complete: This.controller.complete; commands: This.controller.commands.copy(); messages: This.controller._messages.copy(); contexts: This.controller._contexts.copy(); contextMap: OB Copy(This.controller.SYSTEM_WORKER_CONTEXT); publicResponseRestored: sameReference(This.controller.onResponse; This.responseHandler); publicTerminationRestored: sameReference(This.controller.onTerminate; This.terminationHandler); safeToReuse: $safe})
	scheduleCheck($safe; $label+"-state"; This.report; "regression")
	$safe:=$safe && $original

Function idle()->$idle : Boolean
	$idle:=(This.controller.worker=Null) && This.controller.complete && (This.controller.commands.length=0) && (This.controller._messages.length=0) && (This.controller._contexts.length=0) && sameReference(This.controller.onResponse; This.responseHandler) && sameReference(This.controller.onTerminate; This.terminationHandler)

Function advance()
	This.caseIndex+=1
	var $safe : Boolean
	Case of
		: (This.caseIndex=1)
			$safe:=This.reject(False; "reject-single")
			This.label:="reuse-single"
		: (This.caseIndex=2)
			$safe:=This.reject(True; "reject-batch")
			This.label:="reuse-batch"
		: (This.caseIndex=3)
			$safe:=This.reject(False; "reject-repeat-1")
			If ($safe)
				$safe:=This.reject(False; "reject-repeat-2")
			End if
			This.label:="reuse-repeated"
	End case
	If (Not($safe))
		// Baseline must fail here without ever accepting a command with wrapped saved handlers.
		This.report.unsafeReusePrevented:=True
		This.finish(False)
		return
	End if
	This.phase:="reuse"
	This.eventStart:=This.report.events.length
	This.expectedEvents:=2
	This.constructing:=True
	This.controller.execute("/usr/bin/true"; Null; This.label)
	This.constructing:=False
	If (This.controller.worker#Null)
		This.workers.push(This.controller.worker)
	End if

Function record($name : Text; $receiver : Object; $worker : 4D.SystemWorker; $event : Object)
	var $current : Integer
	$current:=0
	If ($receiver.worker#Null)
		$current:=$receiver.worker.pid
		If (This.workers.indexOf($receiver.worker)=-1)
			This.workers.push($receiver.worker)
		End if
	End if
	If (This.workers.indexOf($worker)=-1)
		This.workers.push($worker)
	End if
	If (This.report.events.length<32)
		This.report.events.push({name: $name; phase: This.phase; pid: $worker.pid; type: $event.type; context: $event.context; exitCode: $worker.exitCode; receiver: sameReference($receiver; This.controller); process: Process info(Current process); constructionActive: This.constructing; currentPID: $current; complete: This.controller.complete})
	Else
		This.report.errors.push("event-overflow")
	End if

Function tick()
	This.ticks+=1
	This.report.turns.push({turn: This.ticks; phase: This.phase; process: Process info(Current process)})
	If ((Milliseconds-This.started)>12000) || (This.ticks>120)
		If (This.phase#"cleanup")
			This.report.errors.push("bounded-worker-timeout")
			This.finish(False)
		End if
	End if
	Case of
		: (This.phase="reuse") || (This.phase="normal")
			If (This.idle()) && (This.report.events.length>=(This.eventStart+This.expectedEvents))
				var $events : Collection
				var $valid : Boolean
				$events:=This.report.events.slice(This.eventStart)
				$valid:=$events.length=This.expectedEvents
				If ($valid)
					$valid:=$events.every(Formula($1.value.receiver && ($1.value.process.ID=$2) && ($1.value.process.type=5)); This.report.ownerProcess.ID)
					var $i : Integer
					For ($i; 0; This.expectedEvents-1; 2)
						$valid:=$valid && ($events[$i].name="response") && ($events[$i+1].name="termination") && ($events[$i].pid=$events[$i+1].pid) && ($events[$i+1].exitCode=0)
					End for
				End if
				If (This.phase="reuse")
					If ($valid)
						$valid:=$events[0].context=This.label
					End if
					scheduleCheck($valid; This.label; This.report; "regression")
					If (This.caseIndex<3)
						This.advance()
					Else
						This.phase:="normal"
						This.eventStart:=This.report.events.length
						This.expectedEvents:=4
						This.constructing:=True
						This.controller.execute(["/bin/sleep 0.1"; "/bin/sleep 0.5"]; [Null; Null]; ["first"; "second"])
						This.constructing:=False
						If (This.controller.worker#Null)
							This.workers.push(This.controller.worker)
						End if
					End if
				Else
					If ($valid)
						$valid:=($events[0].context="first") && ($events[2].context="second") && ($events[0].pid#$events[2].pid)
					End if
					scheduleCheck($valid; "normal-queue"; This.report; "regression")
					var $old : Boolean
					$old:=False
					If ($events.length=4)
						$old:=($events[1].currentPID=$events[2].pid) && Not($events[1].complete)
					End if
					scheduleCheck($old; "native-old-termination"; This.report; "regression")
					This.phase:="late"
					This.windowStarted:=Milliseconds
					This.eventStart:=This.report.events.length
				End if
			End if
		: (This.phase="late")
			If ((Milliseconds-This.windowStarted)>=1000)
				scheduleCheck(This.report.events.length=This.eventStart; "late-event-window"; This.report; "regression")
				This.finish(True)
			End if
		: (This.phase="cleanup")
			If ((Milliseconds-This.windowStarted)>=1000)
				var $clean : Boolean
				$clean:=True
				var $owned : 4D.SystemWorker
				This.report.cleanup:=[]
				For each ($owned; This.workers)
					$clean:=$clean && $owned.terminated
					This.report.cleanup.push({pid: $owned.pid; terminated: $owned.terminated})
				End for each
				scheduleCheck($clean; "final-cleanup"; This.report; "regression")
				scheduleCheck(This.report.events.every(Formula(Not($1.value.constructionActive))); "constructor-callback-order"; This.report; "regression")
				var $process : Object
				$process:=Process info(Current process)
				scheduleCheck((This.report.turns.length>1) && ($process.ID=This.report.ownerProcess.ID) && ($process.type=5) && (This.report.ownerProcess.number#1); "worker-owner-lifetime"; This.report; "regression")
				This.report.reportProcess:=$process
				This.report.complete:=True
				This.report.rejectionCleanupVerified:=This.finishingSuccess && (This.report.errors.length=0)
				File(This.path).setText(JSON Stringify(This.report))
				Use (This.done)
					This.done.complete:=True
				End use
				KILL WORKER(Current process)
			End if
	End case
	File(This.path).setText(JSON Stringify(This.report))

Function finish($success : Boolean)
	This.finishingSuccess:=$success
	This.phase:="cleanup"
	This.windowStarted:=Milliseconds
	This.controller.commands.clear()
	If (This.controller.worker#Null)
		If (This.workers.indexOf(This.controller.worker)=-1)
			This.workers.push(This.controller.worker)
		End if
	End if
	var $owned : 4D.SystemWorker
	For each ($owned; This.workers)
		If (Not($owned.terminated))
			$owned.terminate()
		End if
	End for each
