property hashCalls : Integer
Class extends IntegrityModel

Class constructor()
	Super()
	This.hashCalls:=0

Function _hash($file : 4D.File) : Object
	This.hashCalls+=1
	var $record : Object
	$record:=This.files.first()
	This.onDownload($record.oid; $record.downloadId)
	return Super._hash($file)
