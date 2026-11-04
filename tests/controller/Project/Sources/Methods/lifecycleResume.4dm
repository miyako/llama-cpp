var $path : Text
var $parameter : Integer
$parameter:=Get database parameter(User param value; $path)
File($path+".callback-resume.json").setText(JSON Stringify({errors: Last errors; number: Current process; process: rejectionProcess; handler: Method called on error(ek local); method: Error method; line: Error line; formula: Error formula}))
