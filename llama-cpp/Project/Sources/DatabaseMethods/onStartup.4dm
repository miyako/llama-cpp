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
        embeddings
    */
	
	$port:=8083
	
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
	
/*
        chat completion
    */
	
	$port:=8084
	
	$folder:=$homeFolder.folder("qwen2.5-1.5b-instruct-q4_k_m")  //where to keep the repo
	$path:="qwen2.5-1.5b-instruct-q4_k_m.gguf"  //path to the file
	$URL:="Qwen/Qwen2.5-1.5B-Instruct-GGUF"  //path to the repo
	
	$huggingface:=cs:C1710.event.huggingface.new($folder; $URL; $path)
	$huggingfaces:=cs:C1710.event.huggingfaces.new([$huggingface])
	
	$options:={\
		ctx_size: 128000; \
		batch_size: 8192; \
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
		jinja: True:C214; \
		flash_attn: "on"; \
		cache_type_v: "q8_0"; \
		cache_type_k: "q8_0"}
	
	//$llama:=cs.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
	
End if 