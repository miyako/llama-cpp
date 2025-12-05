//%attributes = {"invisible":true}
var $llama : cs:C1710.llama

If (False:C215)
	$llama:=cs:C1710.llama.new()  //default
Else 
	var $modelsFolder : 4D:C1709.Folder
	$modelsFolder:=Folder:C1567(fk home folder:K87:24).folder(".llama-cpp")
	var $lang; $URL : Text
	var $file : 4D:C1709.File
	$lang:=Get database localization:C1009(Current localization:K5:22)
	Case of 
		: ($lang="ja")
			$file:=$modelsFolder.file("Llama-3-ELYZA-JP-8B-q4_k_m.gguf")
			$URL:="https://huggingface.co/elyza/Llama-3-ELYZA-JP-8B-GGUF/resolve/main/Llama-3-ELYZA-JP-8B-q4_k_m.gguf"
		Else 
			$file:=$modelsFolder.file("nomic-embed-text-v1.5.f16.gguf")
			$URL:="https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.f16.gguf"
	End case 
	var $port : Integer
	$port:=8080
	
/*
embeddings
*/
	
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
		repeat_penalty: 1.1}; Formula:C1597(ALERT:C41(This:C1470.file.name+($1.success ? " started!" : " did not start..."))))
	
/*
chat/completion (with images)
*/
	
	$file:=$modelsFolder.file("Qwen2-VL-2B-Instruct-Q4_K_M")
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
		repeat_penalty: 1.1}; Formula:C1597(ALERT:C41(This:C1470.file.name+($1.success ? " started!" : " did not start..."))))
	
End if 