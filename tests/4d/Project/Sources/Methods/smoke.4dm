ON ERR CALL("catchError")
var $state : Object
$state:={errors: []; passed: 0; callbacks: []; successCallbacks: 0; compiledMode: Is compiled mode}
var $root : 4D.Folder
$root:=Folder("/RESOURCES").folder("tiny-fixtures")
$root.create()
var $good; $bad; $fresh; $other; $legacy : 4D.File
$good:=$root.file("model with spaces.gguf")
$bad:=$root.file("same-size-corrupt.gguf")
$fresh:=$root.file("fresh.gguf")
$other:=$root.file("other.gguf")
$legacy:=$root.file("legacy.gguf")
$good.setText("abc"; "US-ASCII"; Document unchanged)
$bad.setText("abd"; "US-ASCII"; Document unchanged)
$other.setText("abc"; "US-ASCII"; Document unchanged)
$legacy.setText("abc"; "US-ASCII"; Document unchanged)
var $digest : Text
$digest:="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
var $worker : cs.workers.worker
$worker:=cs.workers.worker.new()
var $before : Integer
var $model : cs.IntegrityModel
$model:=cs.IntegrityModel.new()
$model.event.onError:=Formula(captureError($state; This; $1; $2))
$model.files:=[record($bad; $digest; "git-pointer")]
$before:=$worker.calls
$model.runDownloads()
If (File("/RESOURCES/baseline").exists)
	var $baselinePath : Text
	var $baselineParameter : Integer
	$baselineParameter:=Get database parameter(User param value; $baselinePath)
	File($baselinePath).setText(JSON Stringify({errors: []; corruptStarts: $worker.calls-$before; cacheBytes: $bad.size; cacheContent: $bad.getText()}))
	QUIT 4D
	return
End if
check($worker.calls=$before; "Same-size corrupt cache started"; $state)
check($model.integrity.failed; "Mismatch did not latch failure"; $state)
check(($state.callbacks.length=1) && ($state.callbacks.first().code=3); "Mismatch error delivery"; $state)
check(($state.callbacks.first().expectedDigest=$digest) && ($state.callbacks.first().actualDigest#$digest); "Digest diagnostics lost"; $state)
check(($model.fixtureReceiverTag="error") && ($model.options.fixtureCallbackOption="error"); "Error callback receiver or (options,error) contract changed"; $state)
check($bad.getText()="abd"; "Mismatch changed original file"; $state)
$model.onDownload("git-pointer")
$model.start()
check($worker.calls=$before; "Late completion or explicit start reopened failed attempt"; $state)
check($state.callbacks.length=1; "Failure callback delivered more than once"; $state)

$model:=cs.IntegrityModel.new()
$model.files:=[record($good; Uppercase($digest); "good")]
$model.event.onSuccess:=Formula(captureSuccess($state; This; $1; $2))
$before:=$worker.calls
$model.runDownloads()
check(($worker.calls=($before+1)) && ($model.integrity.status="verified"); "Valid cached SHA-256 did not start once"; $state)
check($model.integrity.results.length=1; "Valid cache hashed more than once"; $state)
check(($state.successCallbacks=1) && ($model.fixtureReceiverTag="success") && ($model.options.fixtureCallbackOption="success") && $state.successArgumentsMatch; "Success callback receiver or (options,models) contract changed"; $state)
$model.onDownload("good")
$model.onDownload("unknown")
check($worker.calls=($before+1); "Duplicate/unknown completion started again"; $state)

$model:=cs.IntegrityModel.new()
$model.files:=[record($fresh; $digest; "fresh")]
$before:=$worker.calls
$model.runDownloads()
check(($worker.calls=($before+1)) && ($model.integrity.status="verified") && ($fresh.getText()="abc"); "Fresh managed download was not verified"; $state)

$fresh.delete()
$model:=cs.IntegrityModel.new()
$model.options.fixtureContent:="abd"
$model.event.onError:=Formula($state.callbacks.push($2))
$model.files:=[record($fresh; $digest; "fresh-bad")]
$before:=$worker.calls
$model.runDownloads()
check(($worker.calls=$before) && ($model.integrity.failed) && ($fresh.getText()="abd"); "Fresh corrupt download not blocked/preserved"; $state)

$model:=cs.IntegrityModel.new()
$model.files:=[record($good; $digest; "same-oid"); record($other; $digest; "same-oid")]
$before:=$worker.calls
$model.runDownloads()
check(($worker.calls=($before+1)) && ($model.integrity.results.length=2); "Equal oid destinations not independently verified"; $state)

$model:=cs.IntegrityModel.new()
$model.files:=[record($good; $digest; "same-oid"); record($bad; $digest; "same-oid")]
$before:=$worker.calls
$model.runDownloads()
check(($worker.calls=$before) && ($model.integrity.failed); "Equal oid corrupt second destination blessed"; $state)

$model:=cs.IntegrityModel.new()
$model.files:=[record($legacy; ""; $digest)]
$before:=$worker.calls
$model.runDownloads()
check(($worker.calls=($before+1)) && ($model.integrity.status="unverified"); "Legacy cache rejected or Git oid treated as payload hash"; $state)

var $fileRecord : Object
$fileRecord:=record($good; $digest; "file-backed")
$fileRecord.folder:=$good
$model:=cs.IntegrityModel.new()
$model.files:=[$fileRecord]
$before:=$worker.calls
$model.runDownloads()
check(($worker.calls=($before+1)) && ($model.integrity.status="verified"); "File-backed destination failed verification"; $state)

$model:=cs.IntegrityModel.new()
$fileRecord:=record($bad; $digest; "wrong-size")
$fileRecord.size:=100
$model.files:=[$fileRecord]
$before:=$worker.calls
$model.runDownloads()
check(($worker.calls=$before) && ($bad.getText()="abd"); "Known-digest wrong-size cache was replaced/redownloaded"; $state)

var $failure : cs.HashFailureModel
$failure:=cs.HashFailureModel.new()
$failure.hashResult:={success: False; digest: ""; message: "helper unavailable"}
$failure.files:=[record($good; $digest; "helper-error")]
$before:=$worker.calls
$failure.runDownloads()
check(($worker.calls=$before) && ($failure.integrity.failed); "Helper failure fell back to size-only acceptance"; $state)
$state.helperErrorMessage:=$failure.integrity.error.message
check((Position("helper unavailable"; $state.helperErrorMessage)>0) && ($failure.integrity.error.details.message="helper unavailable"); "Helper diagnostic was lost from callback message/details"; $state)

$failure:=cs.HashFailureModel.new()
$failure.hashResult:={success: True; digest: "bad-output"; message: ""}
$failure.files:=[record($good; $digest; "malformed")]
$before:=$worker.calls
$failure.runDownloads()
check(($worker.calls=$before) && ($failure.integrity.failed); "Malformed hash accepted"; $state)

$failure:=cs.HashFailureModel.new()
$failure.hashResult:=Null
$failure.files:=[record($good; $digest; "null-result")]
$before:=$worker.calls
$failure.runDownloads()
check(($worker.calls=$before) && ($failure.integrity.failed); "Null hash result was not an explicit integrity failure"; $state)

$failure:=cs.HashFailureModel.new()
$failure.hashResult:={success: 1; digest: $digest; message: ""}
$failure.files:=[record($good; $digest; "invalid-flag")]
$before:=$worker.calls
$failure.runDownloads()
check(($worker.calls=$before) && ($failure.integrity.failed); "Non-boolean helper success accepted"; $state)

$failure:=cs.HashFailureModel.new()
$failure.hashResult:={success: False; digest: ""; message: "helper failed"}
$failure.event.onError:=42
$failure.files:=[record($good; $digest; "invalid-callback")]
$before:=$worker.calls
$failure.runDownloads()
check(($worker.calls=$before) && ($failure.integrity.failed); "Malformed callback hid integrity failure"; $state)
$failure.event.onError:=Formula(Null)

$model:=cs.IntegrityModel.new()
$fileRecord:=record($legacy; ""; "legacy-malformed")
$fileRecord.lfs:={oid: "@"+$digest}
$model.files:=[$fileRecord]
$before:=$worker.calls
$model.runDownloads()
check(($worker.calls=($before+1)) && ($model.integrity.status="unverified"); "Malformed provider digest changed legacy behavior"; $state)

$fresh.delete()
$other.delete()
$model:=cs.IntegrityModel.new()
$model.options.fixturePending:=[]
$model.files:=[record($fresh; $digest; "deferred-a"); record($other; $digest; "deferred-b")]
$before:=$worker.calls
$model.runDownloads()
$model.runDownloads()
$model.start()
check(($model.options.fixturePending.length=2) && ($worker.calls=$before); "Repeated dispatch or early start bypassed pending verification"; $state)
var $first; $second : Object
$first:=$model.options.fixturePending[0]
$second:=$model.options.fixturePending[1]
$second.complete()
check(($worker.calls=$before) && ($model.files.length=1); "Out-of-order completion started before all files"; $state)
$second.completion.call($model; $second.oid)
check($worker.calls=$before; "Repeated pending completion started worker"; $state)
$first.complete()
check(($worker.calls=($before+1)) && ($model.integrity.results.length=2); "Captured completion IDs lost during deferred dispatch"; $state)
$first.completion.call($model; $first.oid)
check($worker.calls=($before+1); "Duplicate terminal deferred callback started again"; $state)
$model.options.fixturePending.clear()
$first:=Null
$second:=Null

$fresh.delete()
$other.delete()
$model:=cs.IntegrityModel.new()
$model.options.fixturePending:=[]
$model.event.onError:=Formula(captureError($state; This; $1; $2))
$model.files:=[record($fresh; $digest; "late-a"); record($other; $digest; "late-b")]
$before:=$worker.calls
$model.runDownloads()
$model.options.fixtureContent:="abd"
$model.options.fixturePending[1].complete()
$model.options.fixtureContent:="abc"
$model.options.fixturePending[0].complete()
check(($worker.calls=$before) && ($model.integrity.failed) && ($model.integrity.results.length=0); "Late valid completion reopened failed multi-file attempt"; $state)
$model.options.fixturePending.clear()

var $reentrant : cs.ReentrantModel
$reentrant:=cs.ReentrantModel.new()
$reentrant.files:=[record($good; $digest; "reentrant")]
$before:=$worker.calls
$reentrant.runDownloads()
check(($worker.calls=($before+1)) && ($reentrant.hashCalls=1) && ($reentrant.integrity.results.length=1); "Reentrant duplicate hashed or started twice"; $state)

$model:=cs.IntegrityModel.new()
$model.offline:=True
$model.options.model:=$legacy
$before:=$worker.calls
$model.start()
check(($worker.calls=($before+1)) && ($model.integrity.status="unverified"); "Offline legacy start changed"; $state)

$model:=cs.IntegrityModel.new()
$model.options.models_dir:=$root
$before:=$worker.calls
$model.start()
check(($worker.calls=($before+1)) && ($model.integrity.status="unverified"); "Router start changed"; $state)

var $resultPath : Text
var $parameter : Integer
$parameter:=Get database parameter(User param value; $resultPath)
File($resultPath).setText(JSON Stringify($state))
QUIT 4D
