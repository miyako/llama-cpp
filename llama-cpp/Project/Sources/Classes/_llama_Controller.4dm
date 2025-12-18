property stdOut : Text
property stdErr : Text

Class extends _CLI_Controller

Class constructor($CLI : cs:C1710._CLI)
	
	Super:C1705($CLI)
	
	This:C1470.clear()
	
Function clear() : cs:C1710._llama_Controller
	
	This:C1470.stdOut:=""
	This:C1470.stdErr:=""
	
	return This:C1470
	
Function onData($worker : 4D:C1709.SystemWorker; $params : Object)
	
	//This.stdOut+=$params.data
	
	If ($instance.onData#Null:C1517) && (OB Instance of:C1731($instance.onData; 4D:C1709.Function))
		$instance.onData.call(This:C1470; $worker; $params)
	End if 
	
Function onDataError($worker : 4D:C1709.SystemWorker; $params : Object)
	
	//This.stdErr+=$params.data
	
	var $instance : cs:C1710._server
	$instance:=This:C1470.instance
	
	If ($instance.onDataError#Null:C1517) && (OB Instance of:C1731($instance.onDataError; 4D:C1709.Function))
		$instance.onDataError.call(This:C1470; $worker; $params)
	End if 
	
Function onResponse($worker : 4D:C1709.SystemWorker; $params : Object)
	
Function onError($worker : 4D:C1709.SystemWorker; $params : Object)
	
Function onTerminate($worker : 4D:C1709.SystemWorker; $params : Object)
	
	var $instance : cs:C1710._server
	$instance:=This:C1470.instance
	
	If ($instance.onTerminate#Null:C1517) && (OB Instance of:C1731($instance.onTerminate; 4D:C1709.Function))
		$instance.onTerminate.call(This:C1470; $worker; $params)
	End if 