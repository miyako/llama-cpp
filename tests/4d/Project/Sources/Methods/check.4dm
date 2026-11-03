#DECLARE($condition : Boolean; $message : Text; $state : Object)
If ($condition)
	$state.passed+=1
Else
	$state.errors.push($message)
End if
File("/RESOURCES/checkpoint.json").setText(JSON Stringify({lastAssertion: $message; passed: $state.passed; errors: $state.errors}))
