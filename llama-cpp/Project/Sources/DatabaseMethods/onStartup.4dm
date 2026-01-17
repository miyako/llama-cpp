var $llama : cs:C1710.llama

If (False:C215)
	$llama:=cs:C1710.llama.new()  //default
Else 
	var $homeFolder : 4D:C1709.Folder
	$homeFolder:=Folder:C1567(fk home folder:K87:24).folder(".GGUF")
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
	$event.onData:=Formula:C1597(LOG EVENT:C667(Into 4D debug message:K38:5; This:C1470.file.fullName+":"+String:C10((This:C1470.range.end/This:C1470.range.length)*100; "###.00%")))
	$event.onData:=Formula:C1597(MESSAGE:C88(This:C1470.file.fullName+":"+String:C10((This:C1470.range.end/This:C1470.range.length)*100; "###.00%")))
	$event.onResponse:=Formula:C1597(LOG EVENT:C667(Into 4D debug message:K38:5; This:C1470.file.fullName+":download complete"))
	$event.onResponse:=Formula:C1597(MESSAGE:C88(This:C1470.file.fullName+":download complete"))
	$event.onTerminate:=Formula:C1597(LOG EVENT:C667(Into 4D debug message:K38:5; (["process"; $1.pid; "terminated!"].join(" "))))
	
/*
embeddings
*/
	
	$port:=8082
	
	$folder:=$homeFolder.folder("nomic-embed-text-v1.Q8_0")  //where to keep the repo
	$path:="nomic-embed-text-v1.Q8_0.gguf"  //path to the file
	$URL:="nomic-ai/nomic-embed-text-v1-GGUF"  //path to the repo
	
	var $embeddings : cs:C1710.event.huggingface
	$embeddings:=cs:C1710.event.huggingface.new($folder; $URL; $path; "embedding")
	$huggingfaces:=cs:C1710.event.huggingfaces.new([$embeddings])
	
	$options:={\
		embeddings: True:C214; \
		threads: 4; \
		threads_batch: 4; \
		threads_http: 4; \
		log_disable: True:C214; \
		n_gpu_layers: -1}
	
	$llama:=cs:C1710.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
	
/*
chat completion
*/
	
	$port:=8083
	
	$folder:=$homeFolder.folder("gemma-2-2b-it-Q4_K_M")  //where to keep the repo
	$path:="gemma-2-2b-it-Q4_K_M.gguf"  //path to the file
	$URL:="bartowski/gemma-2-2b-it-GGUF"  //path to the repo
	
	$options:={\
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
		n_gpu_layers: -1}
	
	$llama:=cs:C1710.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
	
End if 