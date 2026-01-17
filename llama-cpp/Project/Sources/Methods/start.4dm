//%attributes = {"invisible":true,"preemptive":"capable"}
#DECLARE($options : Object; $formula : 4D:C1709.Function)

var $model : cs:C1710._Model
$model:=cs:C1710._Model.new($options.port; $options.huggingfaces; $options.options; $formula; $options.event)

If ($model.offline)
	$model.start()
End if 