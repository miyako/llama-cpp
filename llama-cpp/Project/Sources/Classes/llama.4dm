Class extends _interface

Class constructor($port : Integer; $huggingfaces : cs:C1710.event.huggingfaces; $HOME : 4D:C1709.Folder; $options : Object; $event : cs:C1710.event.event)
	
	Super:C1705()
	
	var $llama : cs:C1710.workers.worker
	$llama:=cs:C1710.workers.worker.new(cs:C1710._server)
	
	If (Not:C34($llama.isRunning($port)))
		
		If (Not:C34(OB Instance of:C1731($HOME; 4D:C1709.Folder))) || (Not:C34($HOME.exists))
			$HOME:=Folder:C1567(fk home folder:K87:24).folder(".GGUF")
		End if 
		
		If ($huggingfaces=Null:C1517) || (Not:C34(OB Instance of:C1731($huggingfaces; cs:C1710.event.huggingfaces))) || ($huggingfaces.huggingfaces.length=0)
			$folder:=$HOME.folder("nomic-embed-text-v1.Q8_0")  //where to keep the repo
			$path:="nomic-ai/nomic-embed-text-v1-GGUF/resolve/main/nomic-embed-text-v1.Q8_0.gguf"  //path to the file
			$URL:="nomic-ai/nomic-embed-text-v1-GGUF"  //path to the repo
			$embeddings:=cs:C1710.event.huggingface.new($folder; $URL; $path; "embedding")
			
			$huggingfaces:=cs:C1710.event.huggingfaces.new([$embeddings])
			$options:={\
				ctx_size: 2048; \
				batch_size: 2048; \
				threads: 4; \
				threads_batch: 4; \
				threads_http: 4; \
				temp: 0.7; \
				top_k: 40; \
				top_p: 0.9; \
				log_disable: True:C214; \
				repeat_penalty: 1.1; \
				n_gpu_layers: -1}
		End if 
		
		If ($port=0) || ($port<0) || ($port>65535)
			$port:=8080
		End if 
		
		This:C1470._main($port; $huggingfaces; $HOME; $options; $event)
		
	End if 
	
Function _main($port : Integer; $huggingfaces : cs:C1710.event.huggingfaces; $HOME : 4D:C1709.Folder; $options : Object; $event : cs:C1710.event.event)
	
	main({name: Split string:C1554(Current method name:C684; "."; sk trim spaces:K86:2).first(); port: $port; huggingfaces: $huggingfaces; HOME: $HOME; options: $options; event: $event}; This:C1470._onTCP)