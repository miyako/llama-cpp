#DECLARE($condition : Boolean; $name : Text; $report : Object; $kind : Text)
$report.checks.push({id: $name; passed: $condition; kind: $kind})
If (Not($condition))
	$report.errors.push($name)
End if
var $path : Text
var $parameter : Integer
$parameter:=Get database parameter(User param value; $path)
File($path).setText(JSON Stringify($report))
