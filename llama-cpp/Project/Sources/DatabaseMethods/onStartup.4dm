var $llama : cs:C1710.llama

If (False:C215)
	$llama:=cs:C1710.llama.new()  //default
Else 
	var $homeFolder : 4D:C1709.Folder
	$homeFolder:=Folder:C1567(fk home folder:K87:24).folder(".llama-cpp")
	var $file : 4D:C1709.File
	var $URL : Text
	var $port : Integer
	
	var $event : cs:C1710.llamaEvent
	$event:=cs:C1710.llamaEvent.new()
/*
Function onError($params : Object; $error : cs._error)
Function onSuccess($params : Object)
*/
	$event.onError:=Formula:C1597(ALERT:C41($2.message))
	$event.onSuccess:=Formula:C1597(ALERT:C41(This:C1470.file.name+" loaded!"))
	
/*
embeddings
*/
	
	$file:=$homeFolder.file("nomic-embed-text-v1.Q8_0.gguf")
	$URL:="https://huggingface.co/nomic-ai/nomic-embed-text-v1-GGUF/resolve/main/nomic-embed-text-v1.Q8_0.gguf"
	$port:=8080
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
chat completion (with images)
*/
	
	$file:=$homeFolder.file("Qwen2-VL-2B-Instruct-Q4_K_M")
	$URL:="https://huggingface.co/bartowski/Qwen2-VL-2B-Instruct-GGUF/resolve/main/Qwen2-VL-2B-Instruct-Q4_K_M.gguf"
	$port:=8081
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
	
End if 