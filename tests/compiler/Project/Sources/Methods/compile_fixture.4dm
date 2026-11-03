ON ERR CALL("catchError")
var $parameter : Integer
var $configPath : Text
$parameter:=Get database parameter(User param value; $configPath)
var $config : Object
$config:=JSON Parse(File($configPath).getText())
var $components : Collection
$components:=[]
var $path : Text
For each ($path; $config.components)
	$components.push(File($path))
End for each
var $result : Object
$result:=Compile project(File($config.project); {targets: ["x86_64_generic"; "arm64_macOS_lib"]; typeInference: "all"; generateSyntaxFile: True; components: $components})
File($config.report).setText(JSON Stringify($result))
QUIT 4D
