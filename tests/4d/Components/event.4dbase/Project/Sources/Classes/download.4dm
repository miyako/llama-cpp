property owner; options : Object
property file : 4D.File
property oid : Text
property completion : 4D.Function
Class constructor($owner : Object; $file : 4D.File; $folder : Object; $oid : Text; $url : Text; $options : Object; $response : 4D.Function; $event : cs.event; $completion : 4D.Function)
	This.owner:=$owner
	This.file:=$file
	This.oid:=$oid
	This.options:=$options
	This.completion:=$completion

Function head()
	If (Value type(This.options.fixturePending)=Is collection)
		This.options.fixturePending.push(This)
	Else
		This.complete()
	End if

Function complete()
	This.file.parent.create()
	This.file.setText(This.options.fixtureContent=Null ? "abc" : This.options.fixtureContent; "US-ASCII"; Document unchanged)
	This.completion.call(This.owner; This.oid)
