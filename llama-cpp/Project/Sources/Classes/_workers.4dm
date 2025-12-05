property workers : Collection

Class constructor
	
	This:C1470.workers:=[]
	
Function find($port : Integer) : 4D:C1709.SystemWorker
	
	If ($port=0) || ($port<0) || ($port>65535)
		return 
	End if 
	
	var $idx : Integer
	$idx:=This:C1470.workers.findIndex(Formula:C1597($1.value.port=$2); $port)
	If ($idx#-1)
		return This:C1470.workers[$idx].worker
	End if 
	
Function insert($port : Integer; $worker : 4D:C1709.SystemWorker) : 4D:C1709.SystemWorker
	
	var $idx : Integer
	$idx:=This:C1470.workers.findIndex(Formula:C1597($1.value.port=$2); $port)
	If ($idx=-1)
		This:C1470.workers.push({port: $port; worker: $worker})
	End if 
	
Function remove($port : Integer)
	
	var $worker : 4D:C1709.SystemWorker
	var $idx : Integer
	$idx:=This:C1470.workers.findIndex(Formula:C1597($1.value.port=$2); $port)
	If ($idx#-1)
		This:C1470.workers.remove($idx)
	End if 