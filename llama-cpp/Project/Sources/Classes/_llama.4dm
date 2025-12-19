property port : Integer
property onData : 4D:C1709.Function
property onDataError : 4D:C1709.Function
property onTerminate : 4D:C1709.Function

Class extends _CLI

Class constructor($command : Text; $controller : 4D:C1709.Class)
	
	If (Not:C34(OB Instance of:C1731($controller; cs:C1710._llama_Controller)))
		$controller:=cs:C1710._llama_Controller
	End if 
	
	var $program : Text
	
	Case of 
		: ($command="embedding")
			$program:="llama-embedding"
		: ($command="gguf")
			$program:="llama-gguf"
		: ($command="quantize")
			$program:="llama-quantize"
		: ($command="cli")
			$program:="llama-cli"
		: ($command="tokenize")
			$program:="llama-tokenize"
		Else 
			$program:="llama-server"
	End case 
	
	Super:C1705($program; $controller)
	
Function bind($option : Object; $properties : Collection) : cs:C1710._CLI
	
	var $property : Text
	For each ($property; $properties)
		This:C1470[$property]:=$option[$property]
	End for each 
	
	return This:C1470
	
Function get worker() : 4D:C1709.SystemWorker
	
	return This:C1470.controller.worker
	
Function terminate()
	
	This:C1470.controller.terminate()