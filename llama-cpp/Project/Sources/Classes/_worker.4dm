Class constructor
	
	var __WORKER__ : cs:C1710._workers
	
Function start($port : Integer; $option : Object)
	
	If ($option=Null:C1517) || (Value type:C1509($option)#Is object:K8:27)
		return 
	End if 
	
	var $signal : 4D:C1709.Signal
	$signal:=New signal:C1641("llama.cpp")
	
	CALL WORKER:C1389($signal.description; This:C1470._start; $port; $option; $signal)
	
	$signal.wait()
	
Function _start($port : Integer; $option : Object; $signal : 4D:C1709.Signal)
	
	If (Value type:C1509(__WORKER__)=Is object:K8:27) && (OB Instance of:C1731(__WORKER__; cs:C1710._workers))
	Else 
		__WORKER__:=cs:C1710._workers.new()
	End if 
	
	var $worker : 4D:C1709.SystemWorker
	$worker:=__WORKER__.find($port)
	
	If (OB Instance of:C1731($worker; 4D:C1709.SystemWorker)) && (Not:C34($worker.terminated))
		//already started
	Else 
		var $llama : cs:C1710._server
		$llama:=cs:C1710._server.new()
		$worker:=$llama.start($option)
		__WORKER__.insert($port; $worker)
	End if 
	
	$signal.trigger()
	
Function _terminate($signal : 4D:C1709.Signal)
	
	If (Value type:C1509(__WORKER__)=Is object:K8:27) && (OB Instance of:C1731(__WORKER__; cs:C1710._workers))
		
		var $worker : 4D:C1709.SystemWorker
		For each ($worker; __WORKER__.workers)
			If (OB Instance of:C1731($worker; 4D:C1709.SystemWorker)) && (Not:C34($worker.terminated))
				$worker.terminate()
			End if 
		End for each 
	End if 
	
	__WORKER__.workers:=[]
	
	$signal.trigger()
	
Function terminate()
	
	var $signal : 4D:C1709.Signal
	$signal:=New signal:C1641("llama.cpp")
	
	CALL WORKER:C1389($signal.description; This:C1470._terminate; $signal)
	
	$signal.wait()
	
Function _isRunning($port : Integer; $signal : 4D:C1709.Signal)
	
	If (Value type:C1509(__WORKER__)=Is object:K8:27) && (OB Instance of:C1731(__WORKER__; cs:C1710._workers))
	Else 
		__WORKER__:=cs:C1710._workers.new()
	End if 
	
	var $worker : 4D:C1709.SystemWorker
	$worker:=__WORKER__.find($port)
	
	var $isRunning : Boolean
	
	If (OB Instance of:C1731($worker; 4D:C1709.SystemWorker)) && (Not:C34($worker.terminated))
		$isRunning:=True:C214
	End if 
	
	Use ($signal)
		$signal.isRunning:=$isRunning
	End use 
	
	$signal.trigger()
	
Function isRunning($port : Integer) : Boolean
	
	var $signal : 4D:C1709.Signal
	$signal:=New signal:C1641("llama.cpp")
	
	CALL WORKER:C1389($signal.description; This:C1470._isRunning; $port; $signal)
	
	$signal.wait()
	
	return $signal.isRunning