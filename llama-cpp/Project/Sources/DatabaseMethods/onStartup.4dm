var $llama : cs:C1710.llama

If (False:C215)
	$llama:=cs:C1710.llama.new()  //default
Else 
	var $homeFolder : 4D:C1709.Folder
	$homeFolder:=Folder:C1567(fk home folder:K87:24).folder(".GGUF")
	var $file : 4D:C1709.File
	var $URL : Text
	var $port : Integer
	var $huggingface : cs:C1710.event.huggingface
	
	var $event : cs:C1710.event.event
	$event:=cs:C1710.event.event.new()
/*
        Function onError($params : Object; $error : cs.event.error)
        Function onSuccess($params : Object; $models : cs.event.models)
        Function onData($request : 4D.HTTPRequest; $event : Object)
        Function onResponse($request : 4D.HTTPRequest; $event : Object)
        Function onTerminate($worker : 4D.SystemWorker; $params : Object)
    */
	
	$event.onError:=Formula:C1597(ALERT:C41($2.message))
	$event.onSuccess:=Formula:C1597(ALERT:C41($2.models.extract("name").join(",")+" loaded!"))
	$event.onData:=Formula:C1597(LOG EVENT:C667(Into 4D debug message:K38:5; This:C1470.file.fullName+":"+String:C10((This:C1470.range.end/This:C1470.range.length)*100; "###.00%")))
	$event.onData:=Formula:C1597(MESSAGE:C88(This:C1470.file.fullName+":"+String:C10((This:C1470.range.end/This:C1470.range.length)*100; "###.00%")))
	$event.onResponse:=Formula:C1597(LOG EVENT:C667(Into 4D debug message:K38:5; This:C1470.file.fullName+":download complete"))
	$event.onResponse:=Formula:C1597(MESSAGE:C88(This:C1470.file.fullName+":download complete"))
	$event.onTerminate:=Formula:C1597(LOG EVENT:C667(Into 4D debug message:K38:5; (["process"; $1.pid; "terminated!"].join(" "))))
	
/*
	$options:={\
embeddings
*/
	
	If (False:C215)
		
		$port:=8081
		
		$folder:=$homeFolder.folder("jina-embeddings-v4-text-matching-Q4_K_M")  //where to keep the repo
		$path:="jina-embeddings-v4-text-matching-Q4_K_M.gguf"  //path to the file
		$URL:="jinaai/jina-embeddings-v4-text-matching-GGUF"  //path to the repo
		
		$huggingface:=cs:C1710.event.huggingface.new($folder; $URL; $path)
		$huggingfaces:=cs:C1710.event.huggingfaces.new([$huggingface])
		
		$options:={\
			embeddings: True:C214; \
			pooling: "mean"; \
			threads: 4; \
			threads_batch: 4; \
			threads_http: 4; \
			log_disable: True:C214; \
			n_gpu_layers: -1}
		
		//$llama:=cs.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
		
	End if 
	
/*
chat completion
*/
	
	If (False:C215)
		
		$port:=8082
		
		$folder:=$homeFolder.folder("Qwen3-4B-Instruct-2507")  //where to keep the repo
		$path:="Qwen3-4B-Instruct-2507-Q4_K_M.gguf"  //path to the file
		$URL:="keisuke-miyako/Qwen3-4B-Instruct-2507-gguf-q4k_m"  //path to the repo
		
		$options:={\
			ctx_size: 4096; \
			batch_size: 2048; \
			threads: 4; \
			n_predict: -1; \
			threads_batch: 4; \
			threads_http: 4; \
			temp: 0.3; \
			top_k: 40; \
			top_p: 0.9; \
			log_disable: True:C214; \
			repeat_penalty: 1; \
			n_gpu_layers: -1; \
			jinja: True:C214}
		
		$folder:=$homeFolder.folder("translategemma-4b-it")  //where to keep the repo
		$path:="translategemma-4b-it-Q4_K_M.gguf"  //path to the file
		$URL:="keisuke-miyako/translategemma-4b-it-gguf-q4_k_m"  //path to the repo
		
		$huggingface:=cs:C1710.event.huggingface.new($folder; $URL; $path)
		$huggingfaces:=cs:C1710.event.huggingfaces.new([$huggingface])
		
		$llama:=cs:C1710.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
		
	End if 
	
/*
rerank
*/
	
	If (True:C214)
		
		$port:=8082
		
		$folder:=$homeFolder.folder("ms-marco-MiniLM-L6-v2")  //where to keep the repo
		$path:="ms-marco-MiniLM-L6-v2-Q8_0.gguf"  //path to the file
		$URL:="keisuke-miyako/ms-marco-MiniLM-L6-v2-gguf-q8_0"  //path to the repo
		
		$batch_size:=8194
		$ubatch_size:=8194  //max_position_embeddings
		$pooling:="rank"
		$n_gpu_layers:=-1
		
		$options:={\
			embeddings: True:C214; \
			pooling: "rank"; \
			fit: True:C214; \
			log_disable: True:C214; \
			reranking: True:C214}
		
		//$folder:=$homeFolder.folder("jina-reranker-v3")
		//$path:="jina-reranker-v3-Q4_k_m.gguf"
		//$URL:="keisuke-miyako/jina-reranker-v3-gguf-q4_k_m"
		
		//$options:={\
			pooling: $pooling; \
			threads: 4; \
			threads_batch: 4; \
			threads_http: 4; \
			log_disable: True; \
			reranking: True; \
			n_gpu_layers: $n_gpu_layers}
		
		$huggingface:=cs:C1710.event.huggingface.new($folder; $URL; $path)
		$huggingfaces:=cs:C1710.event.huggingfaces.new([$huggingface])
		
		$llama:=cs:C1710.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
		
	End if 
	
End if 