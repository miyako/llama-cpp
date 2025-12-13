//%attributes = {"invisible":true,"preemptive":"capable"}
#DECLARE($params : Object; $formula : 4D:C1709.Function; $other : Object)

Case of 
	: (Count parameters:C259=2)
		
		//execute in a worker to process callbacks
		CALL WORKER:C1389(1; Current method name:C684; $params; $formula; {})
		
	: (Count parameters:C259=3)
		
		var $tcp : cs:C1710.tcp.tcp
		$tcp:=cs:C1710.tcp.tcp.new()
		$tcp.check($params; $formula)
		
End case 