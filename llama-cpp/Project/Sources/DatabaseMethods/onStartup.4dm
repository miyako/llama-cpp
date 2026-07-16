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
	
	$port:=8080
	
	$folder:=$homeFolder.folder("Bonsai")
	$path:="Ternary-Bonsai-8B-Q2_0.gguf"
	$URL:="prism-ml/Ternary-Bonsai-8B-gguf"
	//$path:="Ternary-Bonsai-27B-Q2_0.gguf"
	//$URL:="prism-ml/Ternary-Bonsai-27B-gguf"
	$threads:=2
	$batches:=2
	$threads_batch:=2
	$ubatch_size:=512
	$batch_size:=2048
	
	$max_position_embeddings:=16384
	$cache_type_k:="f16"
	$cache_type_v:="f16"
	$n_gpu_layers:=99
	$top_k:=20
	$top_p:=0.95
	$temp:=0.7
	$logFile:=$folder.file("llama.log")
	$folder.create()
	If (Not:C34($logFile.exists))
		$logFile.setContent(4D:C1709.Blob.new())
	End if 
	
	$options:={\
		ctx_size: $max_position_embeddings*$batches; \
		batch_size: $batch_size*$batches; \
		ubatch_size: $ubatch_size; \
		parallel: $batches; \
		threads: $threads; \
		threads_batch: $threads_batch; \
		threads_http: $batches+1; \
		n_gpu_layers: $n_gpu_layers; \
		cache_type_k: $cache_type_k; \
		cache_type_v: $cache_type_v; \
		temp: $temp; \
		top_k: $top_k; \
		top_p: $top_p; \
		log_disable: False:C215; \
		log_file: $logFile; \
		jinja: True:C214}
	
	$huggingface:=cs:C1710.event.huggingface.new($folder; $URL; $path)
	$huggingfaces:=cs:C1710.event.huggingfaces.new([$huggingface])
	
	$llama:=cs:C1710.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
	
End if 