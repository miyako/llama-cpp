property huggingfaces : cs:C1710.event.huggingfaces
property files : Collection
property _models : Collection
property options : Object
property event : cs:C1710.event.event
property _onResponse : 4D:C1709.Function
property offline : Boolean
property integrity : Object
property _downloadsStarted : Boolean
property _downloadsComplete : Boolean

Class constructor($port : Integer; $huggingfaces : cs:C1710.event.huggingfaces; $options : Object; $formula : 4D:C1709.Function; $event : cs:C1710.event.event)
	
	This:C1470.huggingfaces:=$huggingfaces
	This:C1470.event:=$event
	This:C1470._onResponse:=$formula
	This:C1470.options:=$options#Null:C1517 ? $options : {}
	This:C1470.options.onTerminate:=This:C1470.event.onTerminate
	This:C1470.options.onStdErr:=This:C1470.event.onStdErr
	This:C1470.options.onStdOut:=This:C1470.event.onStdOut
	This:C1470.options.port:=$port
	This:C1470.offline:=False:C215
	This:C1470.integrity:={status: "unverified"; failed: False:C215; results: []}
	This:C1470._downloadsStarted:=False:C215
	This:C1470._downloadsComplete:=False:C215
	
	This:C1470.files:=[]
	This:C1470._models:=[]
	
	ARRAY LONGINT:C221($pos; 0)
	ARRAY LONGINT:C221($len; 0)
	
	var $URL : Text
	var $huggingface : cs:C1710.event.huggingface
	$BRANCH:="main"
	var $components : Collection
	
	While (This:C1470.huggingfaces.huggingfaces.length#0)
		$huggingface:=This:C1470.huggingfaces.huggingfaces.shift()
		Case of 
			: (Match regex:C1019("https:\\/\\/huggingface\\.co\\/(.+)"; $huggingface.URL; 1; $pos; $len))
				$URL:=Substring:C12($huggingface.URL; $pos{1}; $len{1})
				$components:=Split string:C1554($URL; "/")
				$USER:=$components.shift()
				$REPO:=$components.shift()
				$API:=["https://huggingface.co/api/models"; $URL; "?recursive=true"].join("/")
			: (Match regex:C1019("(^|\\/[^/]+){2,}"; $huggingface.URL; 1; $pos; $len))
				$URL:=$huggingface.URL
				$components:=Split string:C1554($URL; "/")
				$USER:=$components.shift()
				$REPO:=$components.shift()
				$API:=["https://huggingface.co/api/models"; $USER; $REPO; "tree"; $BRANCH; "?recursive=true"].join("/")
			Else 
				continue
		End case 
		var $request : 4D:C1709.HTTPRequest
		$request:=4D:C1709.HTTPRequest.new($API).wait()
		If ($request.response.status=Null:C1517)
			This:C1470._models.push([$USER; $REPO].join("/"))
			This:C1470.options.model:=$huggingface.folder.file($huggingface.path)  //assuming the 1st path is model
			This:C1470.offline:=True:C214
			continue
		End if 
		If ($request.response.status=200)
			If (Value type:C1509($request.response)=Is object:K8:27)
				var $file : 4D:C1709.File
				Case of 
					: (OB Instance of:C1731($huggingface.folder; 4D:C1709.Folder))
						$resources:=$request.response.body.map(Formula:C1597($1.result:={\
							USER: $2; \
							REPO: $3; \
							BRANCH: $4; \
							type: $1.value.type; \
							domain: $6; \
							name: $7; \
							size: $1.value.size; \
							path: $1.value.path; \
							oid: $1.value.oid; \
							lfs: $1.value.lfs; \
							folder: $5}); $USER; $REPO; $BRANCH; $huggingface.folder; $huggingface.domain; $huggingface.name)
						
						For each ($file; $resources.query("type == :1 and path in :2"; "file"; $huggingface.paths))
							//any file not in option is assumed to be the main model
							var $option : Text
							var $match : Boolean
							$match:=False:C215
							For each ($option; This:C1470.options)
								var $value : Variant
								$value:=This:C1470.options[$option]
								var $vt : Integer
								$vt:=Value type:C1509($value)
								If ($vt#Is object:K8:27)
									continue
								End if 
								If (Not:C34(OB Instance of:C1731($value; 4D:C1709.File)))
									continue
								End if 
								If ($file.path=("@"+$value.fullName))
									$match:=True:C214
									break
								End if 
							End for each 
							If ($match)
								This:C1470.files.push($file)  //model: append
							Else 
								This:C1470.files.unshift($file)  //default: prepend
							End if 
						End for each 
						This:C1470._models.push([$USER; $REPO].join("/"))
					: (OB Instance of:C1731($huggingface.folder; 4D:C1709.File))
						$file:=$request.response.body.query("path == :1"; $huggingface.name).first()
						If ($file=Null:C1517)
							continue
						End if 
						$file.domain:=$huggingface.domain
						$file.name:=$huggingface.name
						$file.folder:=$huggingface.folder
						$file.USER:=$USER
						$file.REPO:=$REPO
						$file.BRANCH:=$BRANCH
						This:C1470.files.push($file)
						This:C1470._models.push([$USER; $REPO].join("/"))
				End case 
			End if 
		End if 
	End while 
	
Function download()
	
	If (This:C1470._downloadsStarted)
		LOG EVENT:C667(Into 4D debug message; "llama: ignored repeated download dispatch")
		return
	End if
	This:C1470._downloadsStarted:=True:C214
	var $pending : Collection
	$pending:=This:C1470.files
	var $file : Object
	For each ($file; $pending)
		$file.downloadId:=Generate UUID:C1066
	End for each

	For each ($file; $pending)
		If (This:C1470.integrity.failed)
			break
		End if
		var $destination : 4D:C1709.File
		$destination:=OB Instance of:C1731($file.folder; 4D:C1709.Folder) ? $file.folder.file($file.path) : $file.folder
		If ($destination.exists)
			If (This:C1470._expectedDigest($file)#"") || ($destination.size=$file.size)
				This:C1470.onDownload($file.oid; $file.downloadId)
				continue
			End if
		End if
		var $owner : Object
		var $downloadId : Text
		$owner:=This:C1470
		$downloadId:=$file.downloadId
		cs:C1710.event.download.new(\
			This:C1470; \
			OB Instance of:C1731($file.folder; 4D:C1709.Folder) ? $file.folder.file($file.path) : $file.folder; \
			$file.folder; \
			$file.oid; \
			["https://huggingface.co"; $file.USER; $file.REPO; "resolve"; $file.BRANCH; $file.path].join("/"); \
			This:C1470.options; \
			This:C1470._onResponse; \
			This:C1470.event; Formula:C1597($owner.onDownload($1; $downloadId))).head()
	End for each 
	
Function onDownload($oid : Text; $downloadId : Text)
	
	var $matches : Collection
	If ($downloadId#"")
		$matches:=This:C1470.files.query("oid == :1 and downloadId == :2"; $oid; $downloadId)
	Else
		$matches:=This:C1470.files.query("oid == :1"; $oid)
	End if
	If ($matches.length=0)
		LOG EVENT:C667(Into 4D debug message; "llama: ignored unknown or completed download")
	End if
	var $file : Object
	For each ($file; $matches)
		This:C1470._onFileDownload($file.downloadId)
	End for each

Function _onFileDownload($downloadId : Text)

	If (This:C1470.integrity.failed) || (This:C1470._downloadsComplete)
		return
	End if
	var $record : Object
	$record:=This:C1470.files.query("downloadId == :1"; $downloadId).first()
	If ($record=Null:C1517)
		LOG EVENT:C667(Into 4D debug message; "llama: ignored unknown or completed download")
		return
	End if
	If ($record.verifying=True:C214)
		return
	End if
	$record.verifying:=True:C214
	If (Not:C34(This:C1470._verifyFile($record)))
		return
	End if
	// Hashing can yield to other completions while the native worker runs.
	If (This:C1470.integrity.failed) || (This:C1470._downloadsComplete)
		return
	End if
	If (This:C1470.files.query("downloadId == :1"; $downloadId).length=0)
		return
	End if
	This:C1470.files:=This:C1470.files.filter(Formula:C1597($1.value.downloadId#$2); $downloadId)
	
	If (This:C1470.files.length=0)
		This:C1470._downloadsComplete:=True:C214
		This:C1470.integrity.status:=This:C1470.integrity.results.every(Formula:C1597($1.value.status="verified")) ? "verified" : "unverified"
		This:C1470.start()
	End if 

Function _verifyFile($record : Object) : Boolean

	var $file : 4D:C1709.File
	$file:=OB Instance of:C1731($record.folder; 4D:C1709.Folder) ? $record.folder.file($record.path) : $record.folder
	var $expected : Text
	$expected:=This:C1470._expectedDigest($record)
	If ($expected="")
		This:C1470.integrity.results.push({path: $file.path; status: "unverified"; reason: "No supported provider SHA-256"})
		LOG EVENT:C667(Into 4D debug message; "llama: unverified file (no supported provider SHA-256): "+$file.path)
		return True:C214
	End if
	
	var $result : Object
	$result:=This:C1470._hash($file)
	If ($result=Null:C1517)
		This:C1470._integrityError($file; $expected; ""; "Hash component returned no result"; {})
		return False:C215
	End if
	If (Value type:C1509($result.success)#Is Boolean)
		This:C1470._integrityError($file; $expected; ""; "Hash component returned an invalid success flag"; $result)
		return False:C215
	End if
	If (Not:C34($result.success))
		var $message : Text
		$message:="SHA-256 verification failed"
		If (Value type:C1509($result.message)=Is text:K8:3)
			If ($result.message#"")
				$message+=": "+$result.message
			End if
		End if
		This:C1470._integrityError($file; $expected; ""; $message; $result)
		return False:C215
	End if
	If (Value type:C1509($result.digest)#Is text:K8:3)
		This:C1470._integrityError($file; $expected; ""; "Hash component returned a non-text digest"; $result)
		return False:C215
	End if
	If (Not:C34(Match regex:C1019("^[0-9a-fA-F]{64}$"; $result.digest)))
		This:C1470._integrityError($file; $expected; ""; "Hash component returned an invalid SHA-256 digest"; $result)
		return False:C215
	End if
	var $actual : Text
	$actual:=Lowercase($result.digest)
	If ($actual#$expected)
		This:C1470._integrityError($file; $expected; $actual; "SHA-256 mismatch"; $result)
		return False:C215
	End if
	This:C1470.integrity.results.push({path: $file.path; status: "verified"; expected: $expected; actual: $actual})
	return True:C214

Function _expectedDigest($record : Object) : Text

	If (Value type:C1509($record.lfs)=Is object:K8:27)
		If (Value type:C1509($record.lfs.oid)=Is text:K8:3)
			If (Match regex:C1019("^[0-9a-fA-F]{64}$"; $record.lfs.oid))
				return Lowercase($record.lfs.oid)
			End if
		End if
	End if
	return ""

Function _hash($file : 4D:C1709.File) : Object

	return cs:C1710.hash.hash.new().sha256($file)

Function _integrityError($file : 4D:C1709.File; $expected : Text; $actual : Text; $message : Text; $details : Object)

	If (This:C1470.integrity.failed)
		return
	End if
	This:C1470.integrity.failed:=True:C214
	This:C1470.integrity.status:="failed"
	var $error : Object
	$error:=cs:C1710.event.error.new(3; $message+": "+$file.path; cs:C1710.event.models.new())
	$error.file:=$file.path
	$error.expectedDigest:=$expected
	$error.actualDigest:=$actual
	$error.details:=$details
	This:C1470.integrity.error:=$error
	LOG EVENT:C667(Into 4D debug message; "llama: "+$error.message)
	If (This:C1470.event#Null:C1517)
		If (Value type:C1509(This:C1470.event.onError)=Is object:K8:27)
			If (OB Instance of:C1731(This:C1470.event.onError; 4D:C1709.Function))
				This:C1470.event.onError.call(This:C1470; This:C1470.options; $error)
			End if
		End if
	End if

Function models() : cs:C1710.event.models
	//virtual
	return cs:C1710.event.models.new()
	
Function start()
	//virtual