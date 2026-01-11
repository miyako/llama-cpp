var $llama : cs:C1710.llama

If (False:C215)
	$llama:=cs:C1710.llama.new()  //default
Else 
	var $homeFolder : 4D:C1709.Folder
	$homeFolder:=Folder:C1567(fk home folder:K87:24).folder(".llama-cpp")
	var $file : 4D:C1709.File
	var $URL : Text
	var $port : Integer
	
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
	$event.onData:=Formula:C1597(LOG EVENT:C667(Into 4D debug message:K38:5; "download:"+String:C10((This:C1470.range.end/This:C1470.range.length)*100; "###.00%")))
	$event.onResponse:=Formula:C1597(LOG EVENT:C667(Into 4D debug message:K38:5; "download complete"))
	$event.onTerminate:=Formula:C1597(LOG EVENT:C667(Into 4D debug message:K38:5; (["process"; $1.pid; "terminated!"].join(" "))))
	
/*
embeddings
*/
	
	$file:=$homeFolder.file("nomic-embed-text-v1.Q8_0.gguf")
	$URL:="https://huggingface.co/nomic-ai/nomic-embed-text-v1-GGUF/resolve/main/nomic-embed-text-v1.Q8_0.gguf"
	$port:=8082
	$llama:=cs:C1710.llama.new($port; $file; $URL; {\
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
		n_gpu_layers: -1}; $event)
	
/*
chat completion
*/
	
	//$file:=$homeFolder.file("croissantllmchat-v0.1.Q8_0.gguf")
	//$URL:="https://huggingface.co/croissantllm/CroissantLLMChat-v0.1-GGUF/resolve/main/croissantllmchat-v0.1.Q8_0.gguf"
	
	//$file:=$homeFolder.file("croissantllmchat-v0.1.Q4_K_M.gguf")
	//$URL:="https://huggingface.co/croissantllm/CroissantLLMChat-v0.1-GGUF/resolve/main/croissantllmchat-v0.1.Q4_K_M.gguf"
	
	//$file:=$homeFolder.file("gemma-3-1b-it-Q8_0.gguf")
	//$URL:="https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q8_0.gguf"
	
	//$file:=$homeFolder.file("Qwen3-1.7B-Q8_0.gguf")
	//$URL:="https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q8_0.gguf"
	
	//$file:=$homeFolder.file("gemma-2-2b-it-Q4_K_M.gguf")
	//$URL:="https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf"
	
	$port:=8083
	$llama:=cs:C1710.llama.new($port; $file; $URL; {\
		ctx_size: 2048; \
		batch_size: 2048; \
		threads: 4; \
		threads_batch: 4; \
		threads_http: 4; \
		temp: 0.3; \
		top_k: 40; \
		top_p: 0.9; \
		log_disable: True:C214; \
		repeat_penalty: 1; \
		n_gpu_layers: -1}; $event)
	
End if 