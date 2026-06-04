var $llama : cs:C1710.llama

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

var $folder : 4D:C1709.Folder
var $path; $mmproj; $cache_type_k; $cache_type_v : Text
var $n_gpu_layers; $threads; $batches; $ubatch_size; $batch_size; $max_position_embeddings : Integer

/*

embeddings

use models_preset (experimental router mode)
because each model has a different pooling

*/

$n_gpu_layers:=99

var $iniFile : 4D:C1709.File
var $ini : Collection

$ini:=[]
$ini.push("version = 1")

$ini.push("[embeddinggemma]")
$ini.push("model = "+$homeFolder.file("embeddinggemma-300m/embeddinggemma-300m-Q8_0.gguf").path)
$ini.push("pooling = mean")

$ini.push("[bge-m3]")
$ini.push("model = "+$homeFolder.file("bge-m3/bge-m3-Q8_0.gguf").path)
$ini.push("pooling = cls")

$ini.push("[ettin-encoder]")
$ini.push("model = "+$homeFolder.file("ettin-encoder/ettin-encoder-400m-Q8_0.gguf").path)
$ini.push("pooling = mean")

$ini.push("[granite-embedding-multilingual-r2]")
$ini.push("model = "+$homeFolder.file("granite-embedding-multilingual-r2/granite-embedding-311m-multilingual-r2-Q8_0.gguf").path)
$ini.push("pooling = cls")

$ini.push("[nomic-embed-text-v2-moe]")
$ini.push("model = "+$homeFolder.file("nomic-embed-text-v2-moe/nomic-embed-text-v2-moe-Q8_0.gguf").path)
$ini.push("pooling = mean")

$ini.push("[multilingual-e5-base]")
$ini.push("model = "+$homeFolder.file("multilingual-e5-base/multilingual-e5-base-Q8_0.gguf").path)
$ini.push("pooling = mean")

$ini.push("[Qwen3-Embedding-0.6B]")
$ini.push("model = "+$homeFolder.file("Qwen3-Embedding-0.6B/Qwen3-Embedding-0.6B-Q8_0.gguf").path)
$ini.push("pooling = last")

$ini.push("[granite-embedding-english-r2]")
$ini.push("model = "+$homeFolder.file("granite-embedding-english-r2/granite-embedding-english-r2-Q8_0.gguf").path)
$ini.push("pooling = cls")

$ini.push("[nomic-embed-text-v1.5]")
$ini.push("model = "+$homeFolder.file("nomic-embed-text-v1.5/nomic-embed-text-v1.5-Q8_0.gguf").path)
$ini.push("pooling = mean")

$ini.push("[e5-base-v2]")
$ini.push("model = "+$homeFolder.file("e5-base-v2/e5-base-v2-Q8_0.gguf").path)
$ini.push("pooling = mean")

$ini.push("[snowflake-arctic-embed-l-v2.0]")
$ini.push("model = "+$homeFolder.file("snowflake-arctic-embed-l-v2.0/snowflake-arctic-embed-l-v2.0-Q8_0.gguf").path)
$ini.push("pooling = cls")

$ini.push("[gte-modernbert]")
$ini.push("model = "+$homeFolder.file("gte-modernbert/gte-modernbert-base-Q8_0.gguf").path)
$ini.push("pooling = mean")

$ini.push("[snowflake-arctic-embed-l]")
$ini.push("model = "+$homeFolder.file("snowflake-arctic-embed-l/snowflake-arctic-embed-l-Q8_0.gguf").path)
$ini.push("pooling = mean")

$port:=8888
$folder:=$homeFolder.folder("llama-"+String:C10($port))

$iniFile:=$folder.file("models.ini")
$iniFile.setText($ini.join("\n"))

$max_position_embeddings:=1024
$batch_size:=$max_position_embeddings
$ubatch_size:=$max_position_embeddings

$batches:=2
$threads:=2
$threads_batch:=2

$logFile:=$folder.file("llama.log")
$folder.create()
If (Not:C34($logFile.exists))
	$logFile.setContent(4D:C1709.Blob.new())
End if 

$options:={\
embeddings: True:C214; \
models_preset: $iniFile; \
ctx_size: $max_position_embeddings*$batches; \
batch_size: $batch_size*$batches; \
ubatch_size: $ubatch_size; \
parallel: $batches; \
threads: $threads; \
threads_batch: $threads_batch; \
threads_http: $batches+1; \
log_file: $logFile; \
log_disable: False:C215; \
n_gpu_layers: $n_gpu_layers}

$llama:=cs:C1710.llama.new($port; Null:C1517; $homeFolder; $options; $event)

If (False:C215)
	
	$port:=8081
	
	$folder:=$homeFolder.folder("gemma-4-E2B")
	$path:="gemma-4-E2B-it-q4_k_m.gguf"
	$mmproj:="mmproj-F16.gguf"
	$assistant:="gemma-4-E2B-it-assistant-f16.gguf"
	$URL:="keisuke-miyako/gemma-4-E2B-it-gguf"
	$cache_type_k:="q4_0"
	$cache_type_v:="q4_0"
	$n_gpu_layers:=99
	$threads:=6
	$batches:=1
	$ubatch_size:=512
	$batch_size:=2048
	$max_position_embeddings:=8192
	
	var $logFile : 4D:C1709.File
	$logFile:=$folder.file("llama.log")
	$folder.create()
	If (Not:C34($logFile.exists))
		$logFile.setContent(4D:C1709.Blob.new())
	End if 
	
	var $options : Object
	
	$options:={\
		ctx_size: $max_position_embeddings*$batches; \
		batch_size: $batch_size; \
		ubatch_size: $ubatch_size; \
		parallel: $batches; \
		threads: $threads; \
		threads_batch: $threads; \
		threads_http: 2; \
		temp: 1; \
		min_p: 0; \
		top_k: 20; \
		top_p: 0.95; \
		repeat_penalty: 1; \
		presence_penalty: 0; \
		mmproj: $folder.file($mmproj); \
		spec_type: "draft-mtp"; \
		spec_draft_n_max: 3; \
		spec_draft_model: $folder.file($assistant); \
		n_gpu_layers: $n_gpu_layers; \
		log_disable: False:C215; \
		log_file: $logFile; \
		jinja: True:C214}
	
	var $huggingfaces : cs:C1710.event.huggingfaces
	
	$huggingface:=cs:C1710.event.huggingface.new($folder; $URL; [$path; $assistant; $mmproj])
	$huggingfaces:=cs:C1710.event.huggingfaces.new([$huggingface])
	
	$llama:=cs:C1710.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
	
End if 

If (False:C215)
	
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
		fit: "on"; \
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

If (False:C215)
	
	$folder:=$homeFolder.folder("translategemma-4b-it")  //where to keep the repo
	$path:="translategemma-4b-it-Q4_K_M.gguf"  //path to the file
	$URL:="keisuke-miyako/translategemma-4b-it-gguf-q4_k_m"  //path to the repo
	
	$temperature:=0.8  // (default: 0.8)
	$ctx_size:=8192
	$min_p:=0.1  // (default: 0.1, 0.0 = disabled)
	$top_p:=0.9  //(default: 0.9, 1.0 = disabled)
	$top_k:=40  //top-k sampling (default: 40, 0 = disabled)
	$n_gpu_layers:=-1  //max. number of layers to store in VRAM (default: -1)
	$repeat_penalty:=1  //(default: 1.0 = disabled)
	$flash_attn:="auto"
	
	$huggingface:=cs:C1710.event.huggingface.new($folder; $URL; $path)
	$huggingfaces:=cs:C1710.event.huggingfaces.new([$huggingface])
	
	$options:={\
		ctx_size: $ctx_size; \
		temp: $temperature; \
		top_k: $top_k; \
		top_p: $top_p; \
		min_p: $min_p; \
		log_disable: True:C214; \
		repeat_penalty: $repeat_penalty; \
		fit: "on"; \
		flash_attn: $flash_attn; \
		mmproj: $mmproj; \
		jinja: True:C214}
	
	$llama:=cs:C1710.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
	
End if 
