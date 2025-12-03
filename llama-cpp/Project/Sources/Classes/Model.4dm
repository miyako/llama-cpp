property URL : Text
property method : Text
property headers : Object
property dataType : Text
property automaticRedirections : Boolean
property file : 4D:C1709.File
property options : Object

Class constructor($port : Integer; $file : 4D:C1709.File; $URL : Text; $options : Object)
	
	This:C1470.file:=$file
	This:C1470.URL:=$URL
	This:C1470.method:="GET"
	This:C1470.headers:={Accept: "application/vnd.github+json"}
	This:C1470.dataType:="blob"
	This:C1470.automaticRedirections:=True:C214
	This:C1470.options:=$options#Null:C1517 ? $options : {}
	This:C1470.options.embeddings:=True:C214
	This:C1470.options.port:=$port
	This:C1470.options.model:=$file
	
	If (OB Instance of:C1731(This:C1470.file; 4D:C1709.File))
		If (Not:C34(This:C1470.file.exists))
			If (This:C1470.file.parent#Null:C1517)
				This:C1470.file.parent.create()
				4D:C1709.HTTPRequest.new(This:C1470.URL; This:C1470)
			End if 
		Else 
			This:C1470.start()
		End if 
	End if 
	
Function start()
	
	var $llama : cs:C1710._worker
	$llama:=cs:C1710._worker.new()
	
	$llama.start(This:C1470.options)
	
	KILL WORKER:C1390
	
Function onResponse($request : 4D:C1709.HTTPRequest; $event : Object)
	
	If ($request.response.status=200) && ($request.dataType="blob")
		This:C1470.file.setContent($request.response.body)
		This:C1470.start()
	End if 
	
Function onError($request : 4D:C1709.HTTPRequest; $event : Object)