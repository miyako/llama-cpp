property onData : 4D:C1709.Function
property onDataError : 4D:C1709.Function
property onResponse : 4D:C1709.Function
property onError : 4D:C1709.Function
//property onTerminate : 4D.Function

Class extends _CLI_Controller

Class constructor($CLI : cs:C1710._CLI)
	
	Super:C1705($CLI)
	
	//Function onData($worker : 4D.SystemWorker; $params : Object)
	
	//Function onDataError($worker : 4D.SystemWorker; $params : Object)
	
	//Function onResponse($worker : 4D.SystemWorker; $params : Object)
	
	//Function onError($worker : 4D.SystemWorker; $params : Object)
	
Function onTerminate($worker : 4D:C1709.SystemWorker; $params : Object)
	
	var $instance : cs:C1710._server
	$instance:=This:C1470.instance
	
	If ($instance.onTerminate#Null:C1517) && (OB Instance of:C1731($instance.onTerminate; 4D:C1709.Function))
		$instance.onTerminate.call(This:C1470; $worker; $params)
	End if 