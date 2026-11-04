var $path : Text
var $parameter : Integer
$parameter:=Get database parameter(User param value; $path)
File($path+".engine-errors.json").setText(JSON Stringify({errors: Last errors; method: Error method; line: Error line; formula: Error formula}))
