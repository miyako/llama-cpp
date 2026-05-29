property huggingfaces : cs:C1710.event.huggingfaces
property files : Collection
property _models : Collection
property options : Object
property event : cs:C1710.event.event
property _onResponse : 4D:C1709.Function
property offline : Boolean

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
	
	For each ($file; This:C1470.files)
		If ($file.folder.exists)\
			 && (OB Instance of:C1731($file.folder; 4D:C1709.Folder) ? ($file.folder.file($file.path).exists) : ($file.folder.exists))\
			 && (OB Instance of:C1731($file.folder; 4D:C1709.Folder) ? ($file.folder.file($file.path).size=$file.size) : ($file.folder.size=$file.size))
			This:C1470.onDownload($file.oid)
			continue
		End if 
		cs:C1710.event.download.new(\
			This:C1470; \
			OB Instance of:C1731($file.folder; 4D:C1709.Folder) ? $file.folder.file($file.path) : $file.folder; \
			$file.folder; \
			$file.oid; \
			["https://huggingface.co"; $file.USER; $file.REPO; "resolve"; $file.BRANCH; $file.path].join("/"); \
			This:C1470.options; \
			This:C1470._onResponse; \
			This:C1470.event; This:C1470.onDownload).head()
	End for each 
	
Function onDownload($oid : Text)
	
	This:C1470.files:=This:C1470.files.filter(Formula:C1597($1.value.oid#$2); $oid)
	
	If (This:C1470.files.length=0)
		This:C1470.start()
	End if 
	
Function models() : cs:C1710.event.models
	//virtual
	return cs:C1710.event.models.new()
	
Function start()
	//virtual