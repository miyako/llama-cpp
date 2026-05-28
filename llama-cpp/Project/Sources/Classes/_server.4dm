Class extends _llama

Class constructor($controller : 4D:C1709.Class)
	
	Super:C1705("server"; $controller)
	
Function start($option : Object) : 4D:C1709.SystemWorker
	
	This:C1470.bind($option; ["onTerminate"])
	
	var $command : Text
	$command:=This:C1470.escape(This:C1470.executablePath)
	
	Case of 
		: (Value type:C1509($option.model)=Is object:K8:27)\
			 && (OB Instance of:C1731($option.model; 4D:C1709.File))\
			 && ($option.model.exists)
			$command+=" --model "
			$command+=This:C1470.escape(This:C1470.expand($option.model).path)
			$command+=" "
	End case 
	
	var $arg : Object
	var $valueType : Integer
	var $key : Text
	
	For each ($arg; OB Entries:C1720($option))
		Case of 
			: (["model"; "model_url"; "help"; "version"].includes($arg.key))
				continue
		End case 
		$valueType:=Value type:C1509($arg.value)
		$key:=Replace string:C233($arg.key; "_"; "-"; *)
		Case of 
			: ($valueType=Is real:K8:4)
				$command+=(" --"+$key+" "+String:C10($arg.value)+" ")
			: ($valueType=Is text:K8:3)
				$command+=(" --"+$key+" "+This:C1470.escape($arg.value)+" ")
			: ($valueType=Is boolean:K8:9) && ($arg.value)
				$command+=(" --"+$key+" ")
			: ($valueType=Is object:K8:27) && (OB Instance of:C1731($arg.value; 4D:C1709.File)) && ($arg.value.exists)
				$command+=(" --"+$key+" "+This:C1470.escape(This:C1470.expand($arg.value).path))+" "
			: ($valueType=Is collection:K8:32)
				var $value : Variant
				For each ($value; $arg.value)
					$valueTypeValue:=Value type:C1509($value)
					Case of 
						: ($valueTypeValue=Is real:K8:4)
							$command+=(" --"+$key+" "+String:C10($value)+" ")
						: ($valueTypeValue=Is text:K8:3)
							$command+=(" --"+$key+" "+This:C1470.escape($value)+" ")
						: ($valueTypeValue=Is boolean:K8:9) && ($value)
							$command+=(" --"+$key+" ")
						: ($valueTypeValue=Is object:K8:27) && (OB Instance of:C1731($value; 4D:C1709.File)) && ($value.exists)
							$command+=(" --"+$key+" "+This:C1470.escape(This:C1470.expand($value).path))+" "
					End case 
				End for each 
			Else 
				//
		End case 
	End for each 
		
	var $HF_HUB_CACHE; $LLAMA_CACHE : 4D:C1709.Folder
	$HF_HUB_CACHE:=Folder:C1567(Temporary folder:C486; fk platform path:K87:2).folder(Generate UUID:C1066)
	$HF_HUB_CACHE.create()
	
	$LLAMA_CACHE:=Folder:C1567(Temporary folder:C486; fk platform path:K87:2).folder(Generate UUID:C1066)
	$LLAMA_CACHE.create()
	
	This:C1470.controller.variables:={\
		HF_HUB_CACHE: $HF_HUB_CACHE.path; \
		LLAMA_CACHE: $LLAMA_CACHE.path}
	
	return This:C1470.controller.execute($command).worker