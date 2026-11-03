var $path : Text
var $parameter : Integer
$parameter:=Get database parameter(User param value; $path)
File($path+".rejection.json").setText(JSON Stringify(Last errors))
