Class constructor($port : Integer; $file : 4D:C1709.File; $URL : Text; $options : Object; $formula : 4D:C1709.Function)
	
	var $llama : cs:C1710._worker
	$llama:=cs:C1710._worker.new()
	
	If (Not:C34($llama.isRunning($port)))
		
		If (Value type:C1509($file)#Is object:K8:27) || (Not:C34(OB Instance of:C1731($file; 4D:C1709.File))) || ($URL="")
			var $modelsFolder : 4D:C1709.Folder
			$modelsFolder:=Folder:C1567(fk home folder:K87:24).folder(".llama-cpp")
			var $lang : Text
			$lang:=Get database localization:C1009(Current localization:K5:22)
			Case of 
				: ($lang="ja")
					$file:=$modelsFolder.file("Llama-3-ELYZA-JP-8B-q4_k_m.gguf")
					$URL:="https://huggingface.co/elyza/Llama-3-ELYZA-JP-8B-GGUF/resolve/main/Llama-3-ELYZA-JP-8B-q4_k_m.gguf"
				Else 
					$file:=$modelsFolder.file("nomic-embed-text-v1.5.f16.gguf")
					$URL:="https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.f16.gguf"
			End case 
		End if 
		
		If ($port=0) || ($port<0) || ($port>65535)
			$port:=8080
		End if 
		
		CALL WORKER:C1389(OB Class:C1730(This:C1470).name; This:C1470._Start; $port; $file; $URL; $options; $formula)
		
	End if 
	
Function _Start($port : Integer; $file : 4D:C1709.File; $URL : Text; $options : Object; $formula : 4D:C1709.Function)
	
	var $model : cs:C1710.Model
	$model:=cs:C1710.Model.new($port; $file; $URL; $options; $formula)
	
Function terminate()
	
	var $llama : cs:C1710._worker
	$llama:=cs:C1710._worker.new()
	$llama.terminate()