property URL : Text
property method : Text
property headers : Object
property dataType : Text
property automaticRedirections : Boolean
property file : 4D:C1709.File
property options : Object
property _onResponse : 4D:C1709.Function
property _fileHandle : 4D:C1709.FileHandle
property returnResponseBody : Boolean
property decodeData : Boolean
property range : Object
property bufferSize : Integer
property event : cs:C1710.event.event

Class constructor($port : Integer; $file : 4D:C1709.File; $URL : Text; $options : Object; $formula : 4D:C1709.Function; $event : cs:C1710.event.event)
	
	This:C1470.file:=$file
	This:C1470.URL:=$URL
	This:C1470.method:="GET"
	This:C1470.headers:={Accept: "application/vnd.github+json"}
	This:C1470.dataType:="blob"
	This:C1470.automaticRedirections:=True:C214
	This:C1470.options:=$options#Null:C1517 ? $options : {}
	This:C1470.options.embeddings:=True:C214  //not embedding
	This:C1470.options.port:=$port
	This:C1470.options.model:=$file
	This:C1470._onResponse:=$formula
	This:C1470.returnResponseBody:=False:C215
	This:C1470.decodeData:=False:C215
	This:C1470.bufferSize:=10*(1024^2)
	This:C1470.event:=$event
	
	Case of 
		: (OB Instance of:C1731($file; 4D:C1709.File))
			If (Not:C34(This:C1470.file.exists))
				If (This:C1470.file.parent#Null:C1517)
					This:C1470.file.parent.create()
					This:C1470.head()
				End if 
			Else 
				This:C1470.start()
			End if 
		Else 
			//hugging face mode
			This:C1470.options.model:=This:C1470.URL
			This:C1470.file:={name: This:C1470.URL}
			This:C1470.start()
	End case 
	
Function head()
	
	This:C1470.method:="HEAD"
	This:C1470.range:={length: 0; start: 0; end: 0}
	//HEAD; async onResponse not supported
	var $request : 4D:C1709.HTTPRequest
	$request:=4D:C1709.HTTPRequest.new(This:C1470.URL; This:C1470).wait()
	If ($request.response.status=200)
		This:C1470.method:="GET"
		If (Not:C34(This:C1470.decodeData))
			This:C1470.headers["Accept-Encoding"]:="identity"
		End if 
		If (Value type:C1509($request.response.headers["accept-ranges"])=Is text:K8:3) && \
			($request.response.headers["accept-ranges"]="bytes")
			This:C1470.range.length:=Num:C11($request.response.headers["content-length"])
		End if 
		This:C1470._fileHandle:=This:C1470.file.open("write")
		If (This:C1470.range.length#0)
			var $end; $length : Real
			$end:=This:C1470.range.start+(This:C1470.bufferSize-1)
			$length:=This:C1470.range.length-1
			This:C1470.range.end:=$end>=$length ? $length : $end
			This:C1470.headers.Range:="bytes="+String:C10(This:C1470.range.start)+"-"+String:C10(This:C1470.range.end)
		End if 
		4D:C1709.HTTPRequest.new(This:C1470.URL; This:C1470)
	End if 
	
Function start()
	
	var $llama : cs:C1710.workers.worker
	$llama:=cs:C1710.workers.worker.new(cs:C1710._server)
	$llama.start(This:C1470.options.port; This:C1470.options)
	
	If (This:C1470.event#Null:C1517) && (OB Instance of:C1731(This:C1470.event; cs:C1710.event.event))
		var $model : cs:C1710.event.model
		$model:=cs:C1710.event.model.new(This:C1470.options.model.name; Not:C34(This:C1470.options.model.exists))
		var $models : cs:C1710.event.models
		$models:=cs:C1710.event.models.new([$model])
		This:C1470.event.onSuccess.call(This:C1470; This:C1470.options; $models)
	End if 
	
Function terminate()
	
	var $llama : cs:C1710.workers.worker
	$llama:=cs:C1710.workers.worker.new(cs:C1710._server)
	$llama.terminate()
	
Function onData($request : 4D:C1709.HTTPRequest; $event : Object)
	
	If ($request.dataType="blob") && ($event.data#Null:C1517)
		This:C1470._fileHandle.writeBlob($event.data)
	End if 
	
	If (This:C1470.event#Null:C1517) && (OB Instance of:C1731(This:C1470.event; cs:C1710.event.event))
		This:C1470.event.onData.call(This:C1470; $request; $event)
	End if 
	
Function onResponse($request : 4D:C1709.HTTPRequest; $event : Object)
	
	If ($request.dataType="blob") && ($request.response.body#Null:C1517)
		This:C1470._fileHandle.writeBlob($request.response.body)
	End if 
	
	Case of 
		: (This:C1470.range.end=0)  //simple get
			If ($request.response.status=200)
				This:C1470._fileHandle:=Null:C1517
				If (This:C1470.event#Null:C1517) && (OB Instance of:C1731(This:C1470.event; cs:C1710.event.event))
					This:C1470.event.onResponse.call(This:C1470; $request; $event)
				End if 
				This:C1470.start()
			End if 
		Else   //range get
			If ([200; 206].includes($request.response.status))
				This:C1470.range.start:=This:C1470._fileHandle.getSize()
				If (This:C1470.range.start<This:C1470.range.length)
					var $end; $length : Real
					$end:=This:C1470.range.start+(This:C1470.bufferSize-1)
					$length:=This:C1470.range.length-1
					This:C1470.range.end:=$end>=$length ? $length : $end
					This:C1470.headers.Range:="bytes="+String:C10(This:C1470.range.start)+"-"+String:C10(This:C1470.range.end)
					4D:C1709.HTTPRequest.new(This:C1470.URL; This:C1470)
				Else 
					This:C1470._fileHandle:=Null:C1517
					If (This:C1470.event#Null:C1517) && (OB Instance of:C1731(This:C1470.event; cs:C1710.event.event))
						This:C1470.event.onResponse.call(This:C1470; $request; $event)
					End if 
					This:C1470.start()
				End if 
			End if 
			
	End case 
	
Function onError($request : 4D:C1709.HTTPRequest; $event : Object)
	
	If (Value type:C1509(This:C1470._onResponse)=Is object:K8:27) && (OB Instance of:C1731(This:C1470._onResponse; 4D:C1709.Function))
		This:C1470._onResponse.call(This:C1470; {success: False:C215})
		This:C1470._fileHandle:=Null:C1517
		This:C1470.file.delete()
		This:C1470.terminate()
	End if 