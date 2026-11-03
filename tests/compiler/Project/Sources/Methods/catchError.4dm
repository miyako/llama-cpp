var $errors : Collection
$errors:=Last errors
ON ERR CALL("")
var $configPath : Text
var $parameter : Integer
$parameter:=Get database parameter(User param value; $configPath)
var $config : Object
$config:=JSON Parse(File($configPath).getText())
File($config.report).setText(JSON Stringify({errors: $errors; fatal: True; method: ERROR METHOD; line: ERROR LINE; formula: ERROR FORMULA}))
QUIT 4D
