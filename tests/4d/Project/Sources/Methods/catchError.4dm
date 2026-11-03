var $errors : Collection
$errors:=Last errors
ON ERR CALL("")
var $resultPath : Text
var $parameter : Integer
$parameter:=Get database parameter(User param value; $resultPath)
File($resultPath).setText(JSON Stringify({errors: $errors; fatal: True; method: ERROR METHOD; line: ERROR LINE; formula: ERROR FORMULA}))
QUIT 4D
